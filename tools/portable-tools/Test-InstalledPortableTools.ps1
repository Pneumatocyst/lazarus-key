[CmdletBinding()]
param(
    [string]$CatalogPath,
    [string]$DestinationRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'PortableTools'),
    [string[]]$ToolId,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
    $baseRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $developmentCatalog = Join-Path $baseRoot 'manifests\portable-tools.json'
    $deployedCatalog = Join-Path $baseRoot 'Documentation\portable-tools.json'
    $CatalogPath = if (Test-Path -LiteralPath $developmentCatalog) { $developmentCatalog } else { $deployedCatalog }
}

$catalogCheck = & (Join-Path $PSScriptRoot 'Test-PortableToolsCatalog.ps1') -CatalogPath $CatalogPath -PassThru
if (-not $catalogCheck.Valid) { throw "Catalog validation failed: $($catalogCheck.Errors -join '; ')" }
$catalog = Get-Content -LiteralPath (Resolve-Path -LiteralPath $CatalogPath) -Raw | ConvertFrom-Json
$selected = @($catalog.tools)
if ($ToolId) { $selected = @($selected | Where-Object { $ToolId -contains $_.id }) }
$results = [System.Collections.Generic.List[object]]::new()

foreach ($tool in $selected) {
    $directory = Join-Path $DestinationRoot ([string]$tool.install_directory)
    $errors = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        $results.Add([pscustomobject][ordered]@{ ToolId = $tool.id; Name = $tool.name; Status = 'NotInstalled'; Errors = @() })
        continue
    }

    $receiptPath = Join-Path $directory '.lazarus-tool.json'
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
        $errors.Add('Installation receipt is missing.')
    }
    else {
        try {
            $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
            if ($receipt.tool_id -ne $tool.id) { $errors.Add('Receipt tool id does not match the catalog.') }
            if ($receipt.version -ne $tool.version) { $errors.Add('Installed version does not match the catalog.') }
            if ($receipt.archive_sha256 -ne $tool.sha256) { $errors.Add('Receipt archive hash does not match the catalog.') }
        }
        catch { $errors.Add("Installation receipt is invalid: $($_.Exception.Message)") }
    }

    foreach ($launcher in @($tool.launchers)) {
        $launcherPath = Join-Path $directory ([string]$launcher.path)
        if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
            $errors.Add("Launcher is missing: $($launcher.path)")
            continue
        }
        if ($tool.verification.authenticode_required) {
            $signature = Get-AuthenticodeSignature -LiteralPath $launcherPath
            if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate -or
                $signature.SignerCertificate.Subject -notlike "*$($tool.verification.publisher_contains)*") {
                $errors.Add("Publisher verification failed: $($launcher.path)")
            }
        }
    }

    [object[]]$errorArray = $errors.ToArray()
    $results.Add([pscustomobject][ordered]@{
        ToolId = $tool.id
        Name = $tool.name
        Status = $(if ($errorArray.Count -eq 0) { 'Valid' } else { 'Invalid' })
        Errors = $errorArray
    })
}

[object[]]$resultArray = $results.ToArray()
if ($PassThru) { return $resultArray }
foreach ($result in $resultArray) {
    $color = switch ($result.Status) { 'Valid' { 'Green' } 'Invalid' { 'Red' } default { 'DarkGray' } }
    Write-Host "[$($result.Status)] $($result.Name)" -ForegroundColor $color
    foreach ($message in @($result.Errors)) { Write-Host "  $message" -ForegroundColor Red }
}
if (@($resultArray | Where-Object Status -eq 'Invalid').Count -gt 0) { exit 1 }
