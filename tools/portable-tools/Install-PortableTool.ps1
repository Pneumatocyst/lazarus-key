[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string[]]$ToolId,
    [string]$CatalogPath,
    [string]$DestinationRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'PortableTools'),
    [string]$ArchivePath,
    [switch]$AcceptLicense,
    [switch]$Force,
    [switch]$KeepDownload,
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

function Test-SafeRelativePath {
    param([Parameter(Mandatory)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path) -or $Path.Contains(':')) { return $false }
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

function Test-ZipEntryPath {
    param([Parameter(Mandatory)][string]$Path)
    $trimmed = ($Path -replace '\\', '/').TrimEnd('/')
    if (-not $trimmed) { return $true }
    return (Test-SafeRelativePath -Path $trimmed)
}

function Get-FreeBytes {
    param([Parameter(Mandatory)][string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    if ([string]::IsNullOrWhiteSpace($root)) { return $null }
    try { return ([System.IO.DriveInfo]::new($root)).AvailableFreeSpace } catch { return $null }
}

function Test-PublisherSignatures {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$PublisherContains,
        [Parameter(Mandatory)][object[]]$Launchers
    )
    if ($Launchers.Count -eq 0) { throw 'Authenticode verification was required but no launchers were defined.' }
    foreach ($launcher in $Launchers) {
        $binaryPath = Join-Path $Root ([string]$launcher.path)
        $signature = Get-AuthenticodeSignature -LiteralPath $binaryPath
        if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate -or
            $signature.SignerCertificate.Subject -notlike "*$PublisherContains*") {
            throw "Publisher verification failed: $($launcher.path) [$($signature.Status)]"
        }
    }
    return $Launchers.Count
}

if (-not $AcceptLicense) {
    throw 'Review the upstream license metadata and re-run with -AcceptLicense before downloading or installing tools.'
}
if ($ArchivePath -and $ToolId.Count -ne 1) {
    throw '-ArchivePath can be used only when exactly one ToolId is selected.'
}

$catalogResult = & (Join-Path $PSScriptRoot 'Test-PortableToolsCatalog.ps1') -CatalogPath $CatalogPath -PassThru
if (-not $catalogResult.Valid) { throw "Portable-tools catalog validation failed: $($catalogResult.Errors -join '; ')" }
$catalog = Get-Content -LiteralPath (Resolve-Path -LiteralPath $CatalogPath) -Raw | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $DestinationRoot)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}
$destinationRootResolved = (Resolve-Path -LiteralPath $DestinationRoot).Path
$results = [System.Collections.Generic.List[object]]::new()

foreach ($requestedId in $ToolId) {
    $toolMatches = @($catalog.tools | Where-Object { $_.id -eq $requestedId })
    if ($toolMatches.Count -ne 1) { throw "Unknown or duplicate tool id: $requestedId" }
    $tool = $toolMatches[0]
    if (-not (Test-SafeRelativePath -Path ([string]$tool.install_directory))) {
        throw "Unsafe install directory in catalog: $($tool.install_directory)"
    }
    $downloadUri = [uri][string]$tool.download_url
    if ($downloadUri.Scheme -ne 'https' -or
        -not (Test-AllowedHost -HostName $downloadUri.Host -Patterns @($tool.allowed_hosts))) {
        throw "Download URL is outside the tool's allowed HTTPS hosts: $($tool.download_url)"
    }

    $requiredDestinationBytes = [long]$tool.installed_size_estimate_bytes + 33554432
    $destinationFree = Get-FreeBytes -Path $destinationRootResolved
    if ($null -ne $destinationFree -and $destinationFree -lt $requiredDestinationBytes) {
        throw "Insufficient destination space for $($tool.name). Required: $requiredDestinationBytes bytes; available: $destinationFree bytes."
    }

    $downloadedByTool = $false
    $workingArchive = $null
    $stagingParent = Join-Path $destinationRootResolved ".lazarus-staging-$($tool.id)-$([guid]::NewGuid().ToString('N'))"
    $extractRoot = Join-Path $stagingParent 'content'
    $destination = Join-Path $destinationRootResolved ([string]$tool.install_directory)
    $backup = "$destination.backup-$([guid]::NewGuid().ToString('N'))"
    $backupCreated = $false

    try {
        if ($ArchivePath) {
            $workingArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
        }
        else {
            $workingArchive = Join-Path ([System.IO.Path]::GetTempPath()) "Lazarus-$([guid]::NewGuid().ToString('N'))-$($tool.archive_name)"
            $tempFree = Get-FreeBytes -Path ([System.IO.Path]::GetTempPath())
            if ($null -ne $tempFree -and $tempFree -lt ([long]$tool.archive_size_bytes + 16777216)) {
                throw "Insufficient temporary-disk space to download $($tool.name)."
            }
            if ($PSCmdlet.ShouldProcess($tool.download_url, "Download $($tool.name)")) {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $tool.download_url -OutFile $workingArchive -UseBasicParsing
                $downloadedByTool = $true
            }
            else { continue }
        }

        if (-not (Test-Path -LiteralPath $workingArchive -PathType Leaf)) { throw "Archive is missing: $workingArchive" }
        $archiveLength = (Get-Item -LiteralPath $workingArchive).Length
        if ($archiveLength -ne [long]$tool.archive_size_bytes) {
            throw "Archive size mismatch for $($tool.name). Expected $($tool.archive_size_bytes), received $archiveLength."
        }
        $actualHash = (Get-FileHash -LiteralPath $workingArchive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne ([string]$tool.sha256).ToLowerInvariant()) {
            throw "SHA-256 mismatch for $($tool.name). The archive was not installed."
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($workingArchive)
        try {
            foreach ($entry in $zip.Entries) {
                if (-not (Test-ZipEntryPath -Path ([string]$entry.FullName))) {
                    throw "Unsafe ZIP entry path: $($entry.FullName)"
                }
            }
        }
        finally { $zip.Dispose() }

        New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
        Expand-Archive -LiteralPath $workingArchive -DestinationPath $extractRoot -Force
        $payloadRoot = $extractRoot
        if ($tool.strip_single_root) {
            $rootFiles = @(Get-ChildItem -LiteralPath $extractRoot -File)
            $rootDirectories = @(Get-ChildItem -LiteralPath $extractRoot -Directory)
            if ($rootFiles.Count -ne 0 -or $rootDirectories.Count -ne 1) {
                throw "Expected one archive root directory for $($tool.name)."
            }
            $payloadRoot = $rootDirectories[0].FullName
        }

        foreach ($launcher in @($tool.launchers)) {
            if (-not (Test-SafeRelativePath -Path ([string]$launcher.path))) { throw "Unsafe launcher path: $($launcher.path)" }
            if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot ([string]$launcher.path)) -PathType Leaf)) {
                throw "Expected launcher is missing from archive: $($launcher.path)"
            }
        }

        $signaturesChecked = 0
        if ($tool.verification.authenticode_required) {
            $signaturesChecked = Test-PublisherSignatures -Root $payloadRoot `
                -PublisherContains ([string]$tool.verification.publisher_contains) `
                -Launchers @($tool.launchers)
        }

        $receipt = [pscustomobject][ordered]@{
            schema_version = 1
            tool_id = [string]$tool.id
            name = [string]$tool.name
            version = [string]$tool.version
            catalog_project_version = [string]$catalog.project_version
            installed_at = (Get-Date).ToString('o')
            source_url = [string]$tool.download_url
            archive_sha256 = $actualHash
            signatures_checked = $signaturesChecked
            launchers = @($tool.launchers)
        }
        $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $payloadRoot '.lazarus-tool.json') -Encoding UTF8

        if ((Test-Path -LiteralPath $destination) -and -not $Force) {
            throw "Tool is already installed: $destination. Re-run with -Force to replace it."
        }
        if ($PSCmdlet.ShouldProcess($destination, "Install $($tool.name) $($tool.version)")) {
            if (Test-Path -LiteralPath $destination) {
                Move-Item -LiteralPath $destination -Destination $backup
                $backupCreated = $true
            }
            Move-Item -LiteralPath $payloadRoot -Destination $destination
            if ($backupCreated -and (Test-Path -LiteralPath $backup)) {
                Remove-Item -LiteralPath $backup -Recurse -Force
                $backupCreated = $false
            }
        }
        else { continue }

        $results.Add([pscustomobject][ordered]@{
            ToolId = [string]$tool.id
            Name = [string]$tool.name
            Version = [string]$tool.version
            Destination = $destination
            Sha256 = $actualHash
            SignaturesChecked = $signaturesChecked
        })
        if (-not $PassThru) { Write-Host "Installed $($tool.name) $($tool.version) -> $destination" -ForegroundColor Green }
    }
    catch {
        if ($backupCreated -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $destination)) {
            Move-Item -LiteralPath $backup -Destination $destination
            $backupCreated = $false
        }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $stagingParent) { Remove-Item -LiteralPath $stagingParent -Recurse -Force }
        if ($downloadedByTool -and -not $KeepDownload -and $workingArchive -and (Test-Path -LiteralPath $workingArchive)) {
            Remove-Item -LiteralPath $workingArchive -Force
        }
    }
}

if ($PassThru) { return $results.ToArray() }
