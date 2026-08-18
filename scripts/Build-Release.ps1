#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$Version,
    [string]$OutputDirectory,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') -Raw).Trim()
}
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Invalid release version: $Version"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot 'release'
}
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
$archivePath = Join-Path $outputRoot "Lazarus_Key_v$Version.zip"
$hashPath = "$archivePath.sha256"

function Test-ReleaseSourcePath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $normalized = $RelativePath -replace '\\', '/'
    if ($normalized -match '^(?:\.git|release|Reports|Cases|Recovered-Files)(?:/|$)') { return $false }
    if ($normalized -match '^PortableTools/(?!README\.md$)') { return $false }
    if ($normalized -match '(?i)\.(?:iso|img|wim|vhd|vhdx|exe|msi|zip|7z)$') { return $false }
    if ([System.IO.Path]::GetFileName($normalized) -ieq '.lazarus-tool.json') { return $false }
    if ([System.IO.Path]::GetFileName($normalized) -in @('.DS_Store', 'Thumbs.db')) { return $false }
    return $true
}

$files = @(Get-ChildItem -LiteralPath $projectRoot -File -Recurse -Force | ForEach-Object {
    $relative = $_.FullName.Substring($projectRoot.Length).TrimStart([char[]]@('\', '/'))
    if (Test-ReleaseSourcePath -RelativePath $relative) {
        [pscustomobject]@{ File = $_; Relative = ($relative -replace '\\', '/') }
    }
} | Sort-Object Relative)

$required = @(
    'README.md',
    'LICENSE',
    'VERSION',
    '.github/workflows/validate.yml',
    '.github/workflows/release.yml',
    'scripts/Deploy-LazarusKey.ps1',
    'scripts/Validate-LazarusKey.ps1',
    'scripts/Test-WindowsReleaseCandidate.ps1',
    'tools/case-workspace/LazarusCase.psm1',
    "docs/RELEASE-NOTES-v$Version.md"
)
$included = @{}
foreach ($file in $files) { $included[$file.Relative.ToLowerInvariant()] = $true }
foreach ($requiredPath in $required) {
    if (-not $included.ContainsKey($requiredPath.ToLowerInvariant())) {
        throw "Required release file is missing or excluded: $requiredPath"
    }
}
if ($files.Count -eq 0) { throw 'No release files were selected.' }

foreach ($existing in @($archivePath, $hashPath)) {
    if (Test-Path -LiteralPath $existing) { Remove-Item -LiteralPath $existing -Force }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$fixedTimestamp = [DateTimeOffset]::Parse('2000-01-01T00:00:00Z')
$stream = [System.IO.File]::Open($archivePath, [System.IO.FileMode]::CreateNew)
try {
    $archive = New-Object System.IO.Compression.ZipArchive(
        $stream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $false
    )
    try {
        foreach ($item in $files) {
            $entryName = "lazarus-key/$($item.Relative)"
            $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTimestamp
            $input = [System.IO.File]::OpenRead($item.File.FullName)
            $output = $entry.Open()
            try { $input.CopyTo($output) }
            finally { $output.Dispose(); $input.Dispose() }
        }
    }
    finally { $archive.Dispose() }
}
finally { $stream.Dispose() }

$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
"$archiveHash  $([System.IO.Path]::GetFileName($archivePath))" |
    Set-Content -LiteralPath $hashPath -Encoding ASCII

$result = [pscustomobject][ordered]@{
    Version = $Version
    ArchivePath = $archivePath
    HashPath = $hashPath
    Sha256 = $archiveHash
    FileCount = $files.Count
    SizeBytes = (Get-Item -LiteralPath $archivePath).Length
}

if ($PassThru) { return $result }
Write-Host "Release archive: $archivePath" -ForegroundColor Green
Write-Host "SHA-256: $archiveHash" -ForegroundColor DarkCyan
Write-Host "Files: $($result.FileCount)  Bytes: $($result.SizeBytes)"
