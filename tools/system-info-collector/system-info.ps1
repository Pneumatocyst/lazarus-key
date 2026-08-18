[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-LazarusReportsPath {
    $supportedLabels = @('LAZARUSDATA', 'LAZARUS_DATA')

    try {
        $volume = Get-Volume -ErrorAction Stop |
            Where-Object { $_.DriveLetter -and ($supportedLabels -contains $_.FileSystemLabel) } |
            Select-Object -First 1
        if ($volume) {
            return "$($volume.DriveLetter):\Reports"
        }
    }
    catch {
        # Try the CIM fallback below.
    }

    try {
        $volume = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
            Where-Object { $_.DeviceID -and ($supportedLabels -contains $_.VolumeName) } |
            Select-Object -First 1
        if ($volume) {
            return "$($volume.DeviceID)\Reports"
        }
    }
    catch {
        # Fall back to the main Lazarus Key partition.
    }

    # Fall back to the main Lazarus Key partition.
    $scriptsRoot = Split-Path -Parent $PSScriptRoot
    $lazarusRoot = Split-Path -Parent $scriptsRoot
    return (Join-Path $lazarusRoot 'Reports')
}

$reportsRoot = Resolve-LazarusReportsPath
$safeComputer = $env:COMPUTERNAME -replace '[^A-Za-z0-9._-]', '_'
$runDirectory = $null
$caseModule = Join-Path (Split-Path -Parent $PSScriptRoot) 'case-workspace\LazarusCase.psm1'
if (Test-Path -LiteralPath $caseModule -PathType Leaf) {
    Import-Module $caseModule -Force -ErrorAction SilentlyContinue
    if (Get-Command New-LazarusCaseReportDirectory -ErrorAction SilentlyContinue) {
        $runDirectory = New-LazarusCaseReportDirectory -ToolName 'System-Info'
    }
}
if ([string]::IsNullOrWhiteSpace($runDirectory)) {
    $runDirectory = Join-Path $reportsRoot (
        'System-Info-{0}-{1}' -f $safeComputer, (Get-Date -Format 'yyyyMMdd-HHmmss')
    )
}
$collector = Join-Path $PSScriptRoot 'Get-SystemReport.ps1'

try {
    if (-not (Test-Path -LiteralPath $collector -PathType Leaf)) {
        throw "System Info Collector is missing: $collector"
    }

    New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

    Write-Host 'LAZARUS KEY - SYSTEM INFO COLLECTOR' -ForegroundColor Cyan
    Write-Host "Reports: $runDirectory" -ForegroundColor DarkCyan
    Write-Host ''

    & $collector -ExportFormat Text,Json,Csv -OutputDirectory $runDirectory

    Write-Host ''
    Write-Host 'Collection complete.' -ForegroundColor Green
    Start-Process explorer.exe -ArgumentList $runDirectory
}
catch {
    Write-Host ''
    Write-Host "Collection failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host ''
    Read-Host 'Press Enter to close'
}
