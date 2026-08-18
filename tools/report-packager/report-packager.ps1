[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

function Resolve-LazarusReportsPath {
    $supportedLabels = @('LAZARUSDATA', 'LAZARUS_DATA')

    try {
        $volume = Get-Volume -ErrorAction Stop |
            Where-Object { $_.DriveLetter -and ($supportedLabels -contains $_.FileSystemLabel) } |
            Select-Object -First 1
        if ($volume) { return "$($volume.DriveLetter):\Reports" }
    }
    catch {
        # Try the CIM fallback below.
    }

    try {
        $volume = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
            Where-Object { $_.DeviceID -and ($supportedLabels -contains $_.VolumeName) } |
            Select-Object -First 1
        if ($volume) { return "$($volume.DeviceID)\Reports" }
    }
    catch {
        # Fall back to the main Lazarus Key partition.
    }

    $scriptsRoot = Split-Path -Parent $PSScriptRoot
    $lazarusRoot = Split-Path -Parent $scriptsRoot
    return (Join-Path $lazarusRoot 'Reports')
}

$reportsRoot = Resolve-LazarusReportsPath
$bundler = Join-Path $PSScriptRoot 'New-SafeReportBundle.ps1'

try {
    if (-not (Test-Path -LiteralPath $reportsRoot)) {
        New-Item -ItemType Directory -Path $reportsRoot -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $bundler -PathType Leaf)) {
        throw "Safe Report Packager is missing: $bundler"
    }

    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = 'Select one Lazarus Key report folder to sanitize and package.'
    $folderDialog.SelectedPath = $reportsRoot
    $folderDialog.ShowNewFolderButton = $false
    if ($folderDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    $profileChoice = [System.Windows.Forms.MessageBox]::Show(
        "Choose a redaction profile.`r`n`r`nYES = Strict (recommended before external sharing)`r`nNO = Standard`r`nCANCEL = Stop",
        'Lazarus Key - Safe Report Packager',
        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($profileChoice -eq [System.Windows.Forms.DialogResult]::Cancel) { return }
    $profile = if ($profileChoice -eq [System.Windows.Forms.DialogResult]::Yes) { 'Strict' } else { 'Standard' }

    $outputRoot = Join-Path $reportsRoot 'Safe-Bundles'
    Write-Host 'LAZARUS KEY - SAFE REPORT PACKAGER' -ForegroundColor Cyan
    Write-Host "Source: $($folderDialog.SelectedPath)" -ForegroundColor DarkCyan
    Write-Host "Profile: $profile" -ForegroundColor DarkCyan
    Write-Host ''

    $bundle = & $bundler -SourceDirectory $folderDialog.SelectedPath `
        -OutputDirectory $outputRoot -Profile $profile -PassThru

    Write-Host "Bundle: $($bundle.BundlePath)" -ForegroundColor Green
    Write-Host "SHA-256: $($bundle.Sha256)" -ForegroundColor Green
    Write-Host "Files: $($bundle.FilesPackaged)  Redactions: $($bundle.Redactions)"

    Start-Process explorer.exe -ArgumentList $outputRoot
    [System.Windows.Forms.MessageBox]::Show(
        "Sanitized bundle created successfully.`r`n`r`n$($bundle.BundlePath)`r`n`r`nReview the sanitized files before sharing.",
        'Lazarus Key',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}
catch {
    Write-Host ''
    Write-Host "Packaging failed: $($_.Exception.Message)" -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show(
        "Safe report packaging failed.`r`n`r`n$($_.Exception.Message)",
        'Lazarus Key',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
finally {
    Write-Host ''
    Read-Host 'Press Enter to close'
}
