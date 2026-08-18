[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $PSScriptRoot 'fixtures\sample-report'
$bundler = Join-Path $projectRoot 'tools\report-packager\New-SafeReportBundle.ps1'
$verifier = Join-Path $projectRoot 'tools\report-packager\Test-SafeReportBundle.ps1'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "LazarusKey-Test-$([guid]::NewGuid().ToString('N'))"
$sourceCopy = Join-Path $temporaryRoot 'source'
$outputRoot = Join-Path $temporaryRoot 'output'
$expandedRoot = Join-Path $temporaryRoot 'expanded'

try {
    New-Item -ItemType Directory -Path $sourceCopy -Force | Out-Null
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $fixtureRoot '*') -Destination $sourceCopy -Recurse

    $beforeHashes = @{}
    foreach ($file in Get-ChildItem -LiteralPath $sourceCopy -File -Recurse) {
        $beforeHashes[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }

    $bundle = & $bundler -SourceDirectory $sourceCopy -OutputDirectory $outputRoot `
        -Profile Strict -PassThru

    Assert-True -Condition (Test-Path -LiteralPath $bundle.BundlePath -PathType Leaf) `
        -Message 'The report ZIP was not created.'
    Assert-True -Condition (Test-Path -LiteralPath $bundle.BundleHashPath -PathType Leaf) `
        -Message 'The companion ZIP checksum was not created.'
    Assert-True -Condition ($bundle.FilesPackaged -eq 3) `
        -Message "Expected 3 packaged files, found $($bundle.FilesPackaged)."
    Assert-True -Condition ($bundle.Redactions -gt 0) `
        -Message 'The fixture produced no redactions.'

    foreach ($sourcePath in $beforeHashes.Keys) {
        $afterHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        Assert-True -Condition ($afterHash -eq $beforeHashes[$sourcePath]) `
            -Message "The source fixture changed: $sourcePath"
    }

    $verification = & $verifier -BundlePath $bundle.BundlePath -PassThru
    Assert-True -Condition $verification.Valid `
        -Message ("Bundle verification failed: " + ($verification.Errors -join '; '))
    Assert-True -Condition ($verification.FilesChecked -eq 3) `
        -Message "Expected 3 verified files, found $($verification.FilesChecked)."

    Expand-Archive -LiteralPath $bundle.BundlePath -DestinationPath $expandedRoot -Force
    $manifestPath = Join-Path $expandedRoot 'manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-True -Condition ($manifest.tool_version -eq '0.3.0') `
        -Message 'The manifest tool version is incorrect.'
    Assert-True -Condition ($manifest.profile -eq 'strict') `
        -Message 'The manifest profile is incorrect.'
    Assert-True -Condition ($manifest.packaged_file_count -eq 3) `
        -Message 'The manifest packaged file count is incorrect.'

    $sanitizedFiles = @(Get-ChildItem -LiteralPath $expandedRoot -File -Recurse |
        Where-Object { $_.Name -notin @('manifest.json', 'SHA256SUMS.txt') })
    $sanitizedText = ($sanitizedFiles | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw
    }) -join "`n"

    $forbiddenValues = @(
        'LAB-WS-042',
        'CONTOSO\alex.smith',
        'SN-FAKE-123456',
        'alex.smith@example.invalid',
        '192.168.50.25',
        '203.0.113.42',
        '2001:db8::1234',
        'AA-BB-CC-DD-EE-FF',
        'https://support.example.invalid/ticket/12345',
        '11111111-2222-3333-4444-555555555555'
    )
    foreach ($value in $forbiddenValues) {
        Assert-True -Condition (-not $sanitizedText.Contains($value)) `
            -Message "Sensitive fixture value remains in the bundle: $value"
    }

    foreach ($token in @('[REDACTED-HOST]', '[REDACTED-ACCOUNT]', '[REDACTED-SERIAL]', '[REDACTED-IPV4]')) {
        Assert-True -Condition $sanitizedText.Contains($token) `
            -Message "Expected token was not found: $token"
    }

    Get-Content -LiteralPath (Join-Path $expandedRoot 'network.json') -Raw |
        ConvertFrom-Json | Out-Null

    $sumsPath = Join-Path $expandedRoot 'SHA256SUMS.txt'
    $originalSums = @(Get-Content -LiteralPath $sumsPath)
    $originalSums | Select-Object -Skip 1 | Set-Content -LiteralPath $sumsPath -Encoding ASCII
    $missingChecksumVerification = & $verifier -BundlePath $expandedRoot -PassThru
    Assert-True -Condition (-not $missingChecksumVerification.Valid) `
        -Message 'The verifier accepted a bundle with a missing checksum entry.'
    Assert-True -Condition (($missingChecksumVerification.Errors -join '; ').Contains('Checksum entry missing')) `
        -Message 'The verifier did not report the missing checksum entry.'
    $originalSums | Set-Content -LiteralPath $sumsPath -Encoding ASCII

    Set-Content -LiteralPath (Join-Path $expandedRoot 'undeclared.txt') -Value 'unexpected payload' -Encoding UTF8
    $undeclaredVerification = & $verifier -BundlePath $expandedRoot -PassThru
    Assert-True -Condition (-not $undeclaredVerification.Valid) `
        -Message 'The verifier accepted an undeclared payload file.'
    Assert-True -Condition (($undeclaredVerification.Errors -join '; ').Contains('Undeclared file in bundle')) `
        -Message 'The verifier did not report the undeclared payload file.'

    Write-Host 'Safe Report Packager tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
