[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z]:\\?$')]
    [string]$TargetDrive,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$driveLetter = $TargetDrive.Substring(0, 1).ToUpperInvariant()
$root = "$driveLetter`:"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath "$root\")) {
    throw "Target drive $root is not mounted."
}

$volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
Write-Host "Target: $root  Label: $($volume.FileSystemLabel)  Format: $($volume.FileSystem)" -ForegroundColor Cyan
Write-Host 'This script copies project files only. It does not format or repartition the drive.' -ForegroundColor Yellow

if (-not $Force -and (Test-Path -LiteralPath "$root\ventoy\ventoy.json")) {
    throw 'Lazarus Key configuration already exists. Re-run with -Force to update project-managed files.'
}

$directories = @(
    'ISO\Windows',
    'ISO\Linux',
    'ISO\Diagnostics',
    'Launcher',
    'PortableTools',
    'Scripts\System-Info-Collector',
    'Scripts\Network-Troubleshooter',
    'Scripts\Report-Packager',
    'Scripts\Portable-Tools',
    'Scripts\Case-Workspace',
    'Documentation',
    'Reports',
    'Cases',
    'ventoy\theme\lazarus'
)

foreach ($directory in $directories) {
    $path = Join-Path $root $directory
    if ($PSCmdlet.ShouldProcess($path, 'Create directory')) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

$copies = @(
    @{ Source = 'config\ventoy\ventoy.json'; Destination = 'ventoy\ventoy.json' },
    @{ Source = 'config\ventoy\theme\lazarus\theme.txt'; Destination = 'ventoy\theme\lazarus\theme.txt' },
    @{ Source = 'config\ventoy\theme\lazarus\background.png'; Destination = 'ventoy\theme\lazarus\background.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_c.png'; Destination = 'ventoy\theme\lazarus\select_c.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_e.png'; Destination = 'ventoy\theme\lazarus\select_e.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_n.png'; Destination = 'ventoy\theme\lazarus\select_n.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_ne.png'; Destination = 'ventoy\theme\lazarus\select_ne.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_nw.png'; Destination = 'ventoy\theme\lazarus\select_nw.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_s.png'; Destination = 'ventoy\theme\lazarus\select_s.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_se.png'; Destination = 'ventoy\theme\lazarus\select_se.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_sw.png'; Destination = 'ventoy\theme\lazarus\select_sw.png' },
    @{ Source = 'config\ventoy\theme\lazarus\select_w.png'; Destination = 'ventoy\theme\lazarus\select_w.png' },
    @{ Source = 'src\launcher\LazarusKey.ps1'; Destination = 'Launcher\LazarusKey.ps1' },
    @{ Source = 'src\launcher\Launch-LazarusKey.cmd'; Destination = 'Launcher\Launch-LazarusKey.cmd' },
    @{ Source = 'src\launcher\README.md'; Destination = 'Launcher\README.md' },
    @{ Source = 'tools\system-info-collector\Get-SystemReport.ps1'; Destination = 'Scripts\System-Info-Collector\Get-SystemReport.ps1' },
    @{ Source = 'tools\system-info-collector\system-info.ps1'; Destination = 'Scripts\System-Info-Collector\system-info.ps1' },
    @{ Source = 'tools\system-info-collector\system-report.sh'; Destination = 'Scripts\System-Info-Collector\system-report.sh' },
    @{ Source = 'tools\system-info-collector\README.md'; Destination = 'Scripts\System-Info-Collector\README.md' },
    @{ Source = 'tools\network-troubleshooter\Test-NetworkConnection.ps1'; Destination = 'Scripts\Network-Troubleshooter\Test-NetworkConnection.ps1' },
    @{ Source = 'tools\network-troubleshooter\network-troubleshooter.ps1'; Destination = 'Scripts\Network-Troubleshooter\network-troubleshooter.ps1' },
    @{ Source = 'tools\network-troubleshooter\network-test.sh'; Destination = 'Scripts\Network-Troubleshooter\network-test.sh' },
    @{ Source = 'tools\network-troubleshooter\README.md'; Destination = 'Scripts\Network-Troubleshooter\README.md' },
    @{ Source = 'tools\report-packager\New-SafeReportBundle.ps1'; Destination = 'Scripts\Report-Packager\New-SafeReportBundle.ps1' },
    @{ Source = 'tools\report-packager\Test-SafeReportBundle.ps1'; Destination = 'Scripts\Report-Packager\Test-SafeReportBundle.ps1' },
    @{ Source = 'tools\report-packager\report-packager.ps1'; Destination = 'Scripts\Report-Packager\report-packager.ps1' },
    @{ Source = 'tools\report-packager\README.md'; Destination = 'Scripts\Report-Packager\README.md' },
    @{ Source = 'tools\portable-tools\Install-PortableTool.ps1'; Destination = 'Scripts\Portable-Tools\Install-PortableTool.ps1' },
    @{ Source = 'tools\portable-tools\Test-PortableToolsCatalog.ps1'; Destination = 'Scripts\Portable-Tools\Test-PortableToolsCatalog.ps1' },
    @{ Source = 'tools\portable-tools\Test-InstalledPortableTools.ps1'; Destination = 'Scripts\Portable-Tools\Test-InstalledPortableTools.ps1' },
    @{ Source = 'tools\portable-tools\portable-tools-manager.ps1'; Destination = 'Scripts\Portable-Tools\portable-tools-manager.ps1' },
    @{ Source = 'tools\portable-tools\README.md'; Destination = 'Scripts\Portable-Tools\README.md' },
    @{ Source = 'tools\case-workspace\LazarusCase.psm1'; Destination = 'Scripts\Case-Workspace\LazarusCase.psm1' },
    @{ Source = 'tools\case-workspace\New-LazarusCaseHandoff.ps1'; Destination = 'Scripts\Case-Workspace\New-LazarusCaseHandoff.ps1' },
    @{ Source = 'tools\case-workspace\case-workspace.ps1'; Destination = 'Scripts\Case-Workspace\case-workspace.ps1' },
    @{ Source = 'tools\case-workspace\README.md'; Destination = 'Scripts\Case-Workspace\README.md' },
    @{ Source = 'docs\USB-QUICK-START.md'; Destination = 'Documentation\QUICK-START.md' },
    @{ Source = 'docs\REPORT-PRIVACY.md'; Destination = 'Documentation\REPORT-PRIVACY.md' },
    @{ Source = 'docs\PORTABLE-TOOLS.md'; Destination = 'Documentation\PORTABLE-TOOLS.md' },
    @{ Source = 'docs\CASE-WORKSPACE.md'; Destination = 'Documentation\CASE-WORKSPACE.md' },
    @{ Source = 'docs\RELEASE-CHECKLIST-v0.5.0.md'; Destination = 'Documentation\RELEASE-CHECKLIST-v0.5.0.md' },
    @{ Source = 'docs\RELEASE-NOTES-v0.5.0.md'; Destination = 'Documentation\RELEASE-NOTES-v0.5.0.md' },
    @{ Source = 'VERSION'; Destination = 'Documentation\VERSION' },
    @{ Source = 'manifests\images.json'; Destination = 'Documentation\images.json' },
    @{ Source = 'manifests\portable-tools.json'; Destination = 'Documentation\portable-tools.json' }
)

foreach ($copy in $copies) {
    $source = Join-Path $projectRoot $copy.Source
    $destination = Join-Path $root $copy.Destination
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Required project file is missing: $source"
    }
    if ($PSCmdlet.ShouldProcess($destination, 'Copy project file')) {
        Copy-Item -LiteralPath $source -Destination $destination -Force:$Force
    }
}

Write-Host ''
Write-Host 'Lazarus Key project files deployed.' -ForegroundColor Green
Write-Host 'Next:'
Write-Host "  1. Add the required ISO files under $root\ISO."
Write-Host '  2. Test Case Workspace, the technician tools, and Portable Tools Manager from the Windows launcher.'
Write-Host "  3. Run .\scripts\Validate-LazarusKey.ps1 -Root $root\"
Write-Host '  4. Boot-test the USB on an authorized test system.'
