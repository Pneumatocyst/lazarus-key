[CmdletBinding()]
param(
    [string]$CatalogPath,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$errors = [System.Collections.Generic.List[string]]::new()
$catalog = $null

if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
    $baseRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $developmentCatalog = Join-Path $baseRoot 'manifests\portable-tools.json'
    $deployedCatalog = Join-Path $baseRoot 'Documentation\portable-tools.json'
    $CatalogPath = if (Test-Path -LiteralPath $developmentCatalog) { $developmentCatalog } else { $deployedCatalog }
}

function Test-SafeRelativePath {
    param([Parameter(Mandatory)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path) -or $Path.Contains(':')) {
        return $false
    }
    foreach ($segment in (($Path -replace '\\', '/').Split('/'))) {
        if ($segment -in @('', '.', '..')) { return $false }
    }
    return $true
}

function Test-AllowedHost {
    param([Parameter(Mandatory)][string]$HostName, [Parameter(Mandatory)][object[]]$Patterns)
    foreach ($patternValue in $Patterns) {
        $pattern = [string]$patternValue
        if ($pattern.StartsWith('*.')) {
            if ($HostName.EndsWith($pattern.Substring(1), [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        elseif ($HostName.Equals($pattern, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

try {
    $resolvedCatalog = (Resolve-Path -LiteralPath $CatalogPath).Path
    $catalog = Get-Content -LiteralPath $resolvedCatalog -Raw | ConvertFrom-Json
    if ($catalog.schema_version -ne 1) { $errors.Add('Unsupported catalog schema_version.') }
    if ([string]::IsNullOrWhiteSpace([string]$catalog.project_version)) { $errors.Add('project_version is required.') }
    if (-not $catalog.policy.require_https -or -not $catalog.policy.require_sha256) {
        $errors.Add('Catalog policy must require HTTPS and SHA-256.')
    }

    $ids = @{}
    $installDirectories = @{}
    foreach ($tool in @($catalog.tools)) {
        $id = [string]$tool.id
        if ($id -notmatch '^[a-z0-9][a-z0-9-]*$') { $errors.Add("Invalid tool id: $id") }
        if ($ids.ContainsKey($id)) { $errors.Add("Duplicate tool id: $id") } else { $ids[$id] = $true }

        if ([string]::IsNullOrWhiteSpace([string]$tool.name) -or [string]::IsNullOrWhiteSpace([string]$tool.version)) {
            $errors.Add("Tool '$id' is missing a name or version.")
        }
        if ([string]$tool.archive_type -ne 'zip') { $errors.Add("Tool '$id' uses an unsupported archive type.") }
        if ([string]$tool.sha256 -notmatch '^[0-9a-fA-F]{64}$') { $errors.Add("Tool '$id' has an invalid SHA-256 value.") }
        if ([long]$tool.archive_size_bytes -le 0 -or [long]$tool.installed_size_estimate_bytes -le 0) {
            $errors.Add("Tool '$id' has invalid size metadata.")
        }

        $uri = $null
        if (-not [uri]::TryCreate([string]$tool.download_url, [System.UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
            $errors.Add("Tool '$id' does not use an absolute HTTPS download URL.")
        }
        elseif (@($tool.allowed_hosts).Count -eq 0) {
            $errors.Add("Tool '$id' has no allowed_hosts entries.")
        }
        elseif (-not (Test-AllowedHost -HostName $uri.Host -Patterns @($tool.allowed_hosts))) {
            $errors.Add("Tool '$id' download host is not present in allowed_hosts.")
        }

        $installDirectory = [string]$tool.install_directory
        if (-not (Test-SafeRelativePath -Path $installDirectory)) {
            $errors.Add("Tool '$id' has an unsafe install_directory.")
        }
        elseif ($installDirectories.ContainsKey($installDirectory.ToLowerInvariant())) {
            $errors.Add("Duplicate install_directory: $installDirectory")
        }
        else {
            $installDirectories[$installDirectory.ToLowerInvariant()] = $true
        }

        if ([string]::IsNullOrWhiteSpace([string]$tool.license.spdx) -or
            [string]::IsNullOrWhiteSpace([string]$tool.license.url)) {
            $errors.Add("Tool '$id' has incomplete license metadata.")
        }
        else {
            $licenseUri = $null
            if (-not [uri]::TryCreate([string]$tool.license.url, [System.UriKind]::Absolute, [ref]$licenseUri) -or
                $licenseUri.Scheme -ne 'https') {
                $errors.Add("Tool '$id' does not use an absolute HTTPS license URL.")
            }
        }
        if (@($tool.launchers).Count -eq 0) { $errors.Add("Tool '$id' defines no launchers.") }
        foreach ($launcher in @($tool.launchers)) {
            if (-not (Test-SafeRelativePath -Path ([string]$launcher.path))) {
                $errors.Add("Tool '$id' has an unsafe launcher path: $($launcher.path)")
            }
        }
        if ($tool.verification.authenticode_required -and
            [string]::IsNullOrWhiteSpace([string]$tool.verification.publisher_contains)) {
            $errors.Add("Tool '$id' requires Authenticode but has no publisher constraint.")
        }
    }
}
catch {
    $errors.Add($_.Exception.Message)
}

[object[]]$errorArray = $errors.ToArray()
$result = [pscustomobject][ordered]@{
    Valid = ($errorArray.Count -eq 0)
    ToolCount = $(if ($catalog) { @($catalog.tools).Count } else { 0 })
    Errors = $errorArray
}

if ($PassThru) { return $result }
if (-not $result.Valid) {
    foreach ($message in $errorArray) { Write-Host "ERROR: $message" -ForegroundColor Red }
    exit 1
}
Write-Host "Portable-tools catalog passed. Tools: $($result.ToolCount)" -ForegroundColor Green
