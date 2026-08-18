[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$failed = $false

$jsonFiles = @(
    'config\ventoy\ventoy.json',
    'manifests\images.json',
    'manifests\portable-tools.json',
    'tests\fixtures\sample-report\network.json'
)

foreach ($relative in $jsonFiles) {
    $path = Join-Path $projectRoot $relative
    try {
        Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
        Write-Host "PASS JSON: $relative" -ForegroundColor Green
    }
    catch {
        Write-Host "FAIL JSON: $relative - $($_.Exception.Message)" -ForegroundColor Red
        $failed = $true
    }
}

$powerShellFiles = @(Get-ChildItem -Path $projectRoot -File -Recurse |
    Where-Object { $_.Extension -in @('.ps1', '.psm1') })
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        Write-Host "FAIL PS: $($file.FullName)" -ForegroundColor Red
        $parseErrors | ForEach-Object { Write-Host "  $($_.Message)" -ForegroundColor Red }
        $failed = $true
    }
    else {
        Write-Host "PASS PS: $($file.Name)" -ForegroundColor Green
    }
}

if ($failed) {
    exit 1
}

Write-Host 'All project checks passed.' -ForegroundColor Green
