#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$ArchivePath,
    [string]$HashPath,
    [string]$ExpectedVersion,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$entryCount = 0

function Test-SafeArchivePath {
    param([Parameter(Mandatory)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or [System.IO.Path]::IsPathRooted($Path)) { return $false }
    $normalized = $Path -replace '\\', '/'
    if ($normalized.Contains(':') -or -not $normalized.StartsWith('lazarus-key/')) { return $false }
    foreach ($segment in $normalized.Split('/')) {
        if ($segment -in @('', '.', '..')) { return $false }
    }
    return $true
}

try {
    $resolvedArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
    if ([System.IO.Path]::GetExtension($resolvedArchive) -ine '.zip') { throw 'ArchivePath must be a ZIP file.' }
    if ([string]::IsNullOrWhiteSpace($HashPath)) { $HashPath = "$resolvedArchive.sha256" }

    if (-not (Test-Path -LiteralPath $HashPath -PathType Leaf)) {
        $errors.Add("Companion checksum is missing: $HashPath")
    }
    else {
        $line = Get-Content -LiteralPath $HashPath -First 1
        if ($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$') {
            $errors.Add('Companion checksum line is malformed.')
        }
        else {
            $actualHash = (Get-FileHash -LiteralPath $resolvedArchive -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actualHash -ne $Matches[1].ToLowerInvariant()) { $errors.Add('Archive SHA-256 does not match its companion checksum.') }
            if ($Matches[2] -ne [System.IO.Path]::GetFileName($resolvedArchive)) { $errors.Add('Companion checksum names a different archive.') }
        }
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedArchive)
    try {
        $seen = @{}
        foreach ($entry in $archive.Entries) {
            $path = [string]$entry.FullName
            if (-not (Test-SafeArchivePath -Path $path)) { $errors.Add("Unsafe archive path: $path"); continue }
            $key = ($path -replace '\\', '/').ToLowerInvariant()
            if ($seen.ContainsKey($key)) { $errors.Add("Duplicate archive path: $path"); continue }
            $seen[$key] = $true
            $relative = $key.Substring('lazarus-key/'.Length)
            if ($relative -match '^(?:\.git|release|reports|cases|recovered-files)(?:/|$)' -or
                $relative -match '^portabletools/(?!readme\.md$)' -or
                $relative -match '\.(?:iso|img|wim|vhd|vhdx|exe|msi|zip|7z)$' -or
                [System.IO.Path]::GetFileName($relative) -ieq '.lazarus-tool.json') {
                $errors.Add("Forbidden release content: $path")
            }
            $entryCount++
        }

        $required = @(
            'lazarus-key/readme.md',
            'lazarus-key/license',
            'lazarus-key/version',
            'lazarus-key/.github/workflows/release.yml',
            'lazarus-key/scripts/build-release.ps1',
            'lazarus-key/scripts/test-releasearchive.ps1',
            'lazarus-key/scripts/test-windowsreleasecandidate.ps1'
        )
        foreach ($requiredPath in $required) {
            if (-not $seen.ContainsKey($requiredPath)) { $errors.Add("Required archive file is missing: $requiredPath") }
        }

        $versionEntry = $archive.GetEntry('lazarus-key/VERSION')
        if ($null -eq $versionEntry) { $errors.Add('VERSION cannot be checked because it is missing.') }
        else {
            $reader = New-Object System.IO.StreamReader($versionEntry.Open())
            try { $archiveVersion = $reader.ReadToEnd().Trim() }
            finally { $reader.Dispose() }
            if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion) -and $archiveVersion -ne $ExpectedVersion) {
                $errors.Add("Archive VERSION is '$archiveVersion', expected '$ExpectedVersion'.")
            }
            $notesPath = "lazarus-key/docs/release-notes-v$archiveVersion.md".ToLowerInvariant()
            if (-not $seen.ContainsKey($notesPath)) { $errors.Add("Versioned release notes are missing: $notesPath") }
        }
    }
    finally { $archive.Dispose() }
}
catch { $errors.Add($_.Exception.Message) }

$result = [pscustomobject][ordered]@{
    Valid = ($errors.Count -eq 0)
    ArchivePath = $ArchivePath
    EntriesChecked = $entryCount
    Errors = $errors.ToArray()
}
if ($PassThru) { return $result }
if ($result.Valid) {
    Write-Host "Release archive verification passed. Entries checked: $entryCount" -ForegroundColor Green
    exit 0
}
foreach ($message in $result.Errors) { Write-Host "ERROR: $message" -ForegroundColor Red }
Write-Host "Release archive verification failed with $($result.Errors.Count) error(s)." -ForegroundColor Red
exit 1
