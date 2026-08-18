[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $projectRoot 'scripts\Build-Release.ps1'
$verifier = Join-Path $projectRoot 'scripts\Test-ReleaseArchive.ps1'
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') -Raw).Trim()
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "LazarusReleaseTest-$([guid]::NewGuid().ToString('N'))"

try {
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    $first = & $builder -Version $version -OutputDirectory $temporaryRoot -PassThru
    $valid = & $verifier -ArchivePath $first.ArchivePath -HashPath $first.HashPath `
        -ExpectedVersion $version -PassThru
    Assert-True $valid.Valid ('Fresh release archive failed verification: ' + ($valid.Errors -join '; '))

    $firstHash = $first.Sha256
    $second = & $builder -Version $version -OutputDirectory $temporaryRoot -PassThru
    Assert-True ($second.Sha256 -eq $firstHash) 'Two builds from unchanged source produced different hashes.'

    $badHashArchive = Join-Path $temporaryRoot 'bad-hash.zip'
    $badHashCompanion = "$badHashArchive.sha256"
    Copy-Item -LiteralPath $second.ArchivePath -Destination $badHashArchive
    "$('0' * 64)  bad-hash.zip" | Set-Content -LiteralPath $badHashCompanion -Encoding ASCII
    $badHashResult = & $verifier -ArchivePath $badHashArchive -HashPath $badHashCompanion `
        -ExpectedVersion $version -PassThru
    Assert-True (-not $badHashResult.Valid) 'Release verifier accepted a bad companion checksum.'

    $forbiddenArchive = Join-Path $temporaryRoot 'forbidden-content.zip'
    $forbiddenCompanion = "$forbiddenArchive.sha256"
    Copy-Item -LiteralPath $second.ArchivePath -Destination $forbiddenArchive
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($forbiddenArchive, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $zip.CreateEntry('lazarus-key/Reports/sensitive.txt')
        $writer = New-Object System.IO.StreamWriter($entry.Open())
        try { $writer.Write('must never ship') }
        finally { $writer.Dispose() }
    }
    finally { $zip.Dispose() }
    $forbiddenHash = (Get-FileHash -LiteralPath $forbiddenArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    "$forbiddenHash  forbidden-content.zip" | Set-Content -LiteralPath $forbiddenCompanion -Encoding ASCII
    $forbiddenResult = & $verifier -ArchivePath $forbiddenArchive -HashPath $forbiddenCompanion `
        -ExpectedVersion $version -PassThru
    Assert-True (-not $forbiddenResult.Valid) 'Release verifier accepted a bundled Reports payload.'
    Assert-True (($forbiddenResult.Errors -join '; ').Contains('Forbidden release content')) `
        'Release verifier did not identify the forbidden payload.'

    Write-Host 'Release engineering tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}

