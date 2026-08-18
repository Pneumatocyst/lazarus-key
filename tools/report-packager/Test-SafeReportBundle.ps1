[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ })]
    [string]$BundlePath,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$errors = [System.Collections.Generic.List[string]]::new()
$temporaryRoot = $null
$filesChecked = 0

function Test-SafeRelativePath {
    param([Parameter(Mandatory)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path)) {
        return $false
    }
    $normalized = $Path -replace '\\', '/'
    if ($normalized.Contains(':')) { return $false }
    foreach ($segment in $normalized.Split('/')) {
        if ($segment -in @('', '.', '..')) { return $false }
    }
    return $true
}

try {
    $resolvedBundle = (Resolve-Path -LiteralPath $BundlePath).Path
    if (Test-Path -LiteralPath $resolvedBundle -PathType Leaf) {
        if ([System.IO.Path]::GetExtension($resolvedBundle) -ine '.zip') {
            throw 'BundlePath must be a safe-report ZIP or an extracted bundle directory.'
        }
        $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "LazarusKey-Verify-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedBundle)
        try {
            foreach ($entry in $archive.Entries) {
                $entryPath = ([string]$entry.FullName).TrimEnd('/')
                if ($entryPath -and -not (Test-SafeRelativePath -Path $entryPath)) {
                    throw "Unsafe ZIP entry path: $($entry.FullName)"
                }
            }
        }
        finally {
            $archive.Dispose()
        }

        Expand-Archive -LiteralPath $resolvedBundle -DestinationPath $temporaryRoot -Force
        $searchRoot = $temporaryRoot

        $companionHash = "$resolvedBundle.sha256"
        if (Test-Path -LiteralPath $companionHash -PathType Leaf) {
            $expectedZipHash = ((Get-Content -LiteralPath $companionHash -First 1) -split '\s+')[0].ToLowerInvariant()
            $actualZipHash = (Get-FileHash -LiteralPath $resolvedBundle -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($expectedZipHash -ne $actualZipHash) {
                $errors.Add('The ZIP hash does not match its companion .sha256 file.')
            }
        }
    }
    else {
        $searchRoot = $resolvedBundle
    }

    $manifestCandidates = @(Get-ChildItem -LiteralPath $searchRoot -Filter 'manifest.json' -File -Recurse)
    if ($manifestCandidates.Count -ne 1) {
        throw "Expected exactly one manifest.json, found $($manifestCandidates.Count)."
    }

    $manifestPath = $manifestCandidates[0].FullName
    $bundleRoot = Split-Path -Parent $manifestPath
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

    if ($manifest.schema_version -ne 1 -or $manifest.tool -ne 'lazarus-safe-report-packager') {
        $errors.Add('The manifest schema or tool identifier is not supported.')
    }

    $manifestRecords = @($manifest.files)
    if ([int]$manifest.packaged_file_count -ne $manifestRecords.Count) {
        $errors.Add('The manifest packaged_file_count does not match its file records.')
    }

    $declaredPaths = @{}

    foreach ($record in $manifestRecords) {
        $recordPath = [string]$record.path
        if (-not (Test-SafeRelativePath -Path $recordPath)) {
            $errors.Add("Unsafe manifest path: $recordPath")
            continue
        }
        $pathKey = ($recordPath -replace '\\', '/').ToLowerInvariant()
        if ($declaredPaths.ContainsKey($pathKey)) {
            $errors.Add("Duplicate manifest path: $recordPath")
            continue
        }
        $declaredPaths[$pathKey] = $true

        if ([string]$record.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
            $errors.Add("Invalid manifest hash: $recordPath")
            continue
        }

        $relativePath = $recordPath -replace '/', '\'
        $filePath = Join-Path $bundleRoot $relativePath
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            $errors.Add("Missing packaged file: $($record.path)")
            continue
        }
        $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne ([string]$record.sha256).ToLowerInvariant()) {
            $errors.Add("Hash mismatch: $($record.path)")
        }
        $filesChecked++
    }

    $payloadFiles = @(Get-ChildItem -LiteralPath $bundleRoot -File -Recurse |
        Where-Object { $_.FullName -notin @($manifestPath, (Join-Path $bundleRoot 'SHA256SUMS.txt')) })
    foreach ($payloadFile in $payloadFiles) {
        $payloadRelative = $payloadFile.FullName.Substring($bundleRoot.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
        if (-not $declaredPaths.ContainsKey($payloadRelative.ToLowerInvariant())) {
            $errors.Add("Undeclared file in bundle: $payloadRelative")
        }
    }

    $sumsPath = Join-Path $bundleRoot 'SHA256SUMS.txt'
    if (-not (Test-Path -LiteralPath $sumsPath -PathType Leaf)) {
        $errors.Add('SHA256SUMS.txt is missing.')
    }
    else {
        $expectedChecksumPaths = @{}
        foreach ($pathKey in $declaredPaths.Keys) {
            $expectedChecksumPaths[$pathKey] = $true
        }
        $expectedChecksumPaths['manifest.json'] = $true
        $seenChecksumPaths = @{}

        foreach ($line in Get-Content -LiteralPath $sumsPath) {
            if ($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$') {
                $errors.Add("Invalid checksum line: $line")
                continue
            }
            $expected = $Matches[1].ToLowerInvariant()
            $checksumPath = $Matches[2]
            if (-not (Test-SafeRelativePath -Path $checksumPath)) {
                $errors.Add("Unsafe checksum path: $checksumPath")
                continue
            }
            $checksumKey = ($checksumPath -replace '\\', '/').ToLowerInvariant()
            if ($seenChecksumPaths.ContainsKey($checksumKey)) {
                $errors.Add("Duplicate checksum path: $checksumPath")
                continue
            }
            $seenChecksumPaths[$checksumKey] = $true
            if (-not $expectedChecksumPaths.ContainsKey($checksumKey)) {
                $errors.Add("Unexpected checksum target: $checksumPath")
                continue
            }
            $relative = $checksumPath -replace '/', '\'
            $path = Join-Path $bundleRoot $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                $errors.Add("Checksum target missing: $relative")
                continue
            }
            $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($expected -ne $actual) {
                $errors.Add("Checksum mismatch: $relative")
            }
        }


        foreach ($expectedPath in $expectedChecksumPaths.Keys) {
            if (-not $seenChecksumPaths.ContainsKey($expectedPath)) {
                $errors.Add("Checksum entry missing: $expectedPath")
            }
        }
    }
}
catch {
    $errors.Add($_.Exception.Message)
}
finally {
    if ($temporaryRoot -and (Test-Path -LiteralPath $temporaryRoot)) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

[object[]]$errorArray = $errors.ToArray()
$result = [pscustomobject][ordered]@{
    Valid = ($errorArray.Count -eq 0)
    FilesChecked = $filesChecked
    Errors = $errorArray
}

if ($PassThru) {
    return $result
}

if ($result.Valid) {
    Write-Host "Bundle verification passed. Files checked: $filesChecked" -ForegroundColor Green
    exit 0
}

foreach ($message in $errorArray) {
    Write-Host "ERROR: $message" -ForegroundColor Red
}
Write-Host "Bundle verification failed with $($errorArray.Count) error(s)." -ForegroundColor Red
exit 1
