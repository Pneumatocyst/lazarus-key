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
        $runDirectory = New-LazarusCaseReportDirectory -ToolName 'Network-Troubleshooter'
    }
}
if ([string]::IsNullOrWhiteSpace($runDirectory)) {
    $runDirectory = Join-Path $reportsRoot (
        'Network-{0}-{1}' -f $safeComputer, (Get-Date -Format 'yyyyMMdd-HHmmss')
    )
}
$troubleshooter = Join-Path $PSScriptRoot 'Test-NetworkConnection.ps1'

try {
    if (-not (Test-Path -LiteralPath $troubleshooter -PathType Leaf)) {
        throw "Network Troubleshooter is missing: $troubleshooter"
    }

    New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

    Write-Host 'LAZARUS KEY - NETWORK TROUBLESHOOTER' -ForegroundColor Cyan
    Write-Host "Reports: $runDirectory" -ForegroundColor DarkCyan
    Write-Host ''

    $summary = & $troubleshooter -ExportFormat Text,Json,Csv `
        -OutputDirectory $runDirectory -NoExit

    Write-Host ''
    if ($summary.Fail -gt 0) {
        Write-Host (
            'Diagnostics complete: {0} PASS, {1} WARN, {2} FAIL' -f `
                $summary.Pass, $summary.Warn, $summary.Fail
        ) -ForegroundColor Yellow
    }
    else {
        Write-Host (
            'Diagnostics complete: {0} PASS, {1} WARN, 0 FAIL' -f `
                $summary.Pass, $summary.Warn
        ) -ForegroundColor Green
    }

    Start-Process explorer.exe -ArgumentList $runDirectory
}
catch {
    Write-Host ''
    Write-Host "Diagnostics failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host ''
    Read-Host 'Press Enter to close'
}
