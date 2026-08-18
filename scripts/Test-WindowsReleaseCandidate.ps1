#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]:\\?$')][string]$UsbRoot,
    [string]$OutputDirectory,
    [switch]$ManualChecksPassed,
    [switch]$SkipReleaseBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') { throw 'This release gate must run on Windows.' }

$projectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') -Raw).Trim()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot "release\readiness-$stamp"
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
$results = [System.Collections.Generic.List[object]]::new()

function Add-GateResult {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('PASS', 'FAIL', 'PENDING')][string]$Status,
        [Parameter(Mandatory)][string]$Details,
        [string]$LogPath
    )
    $results.Add([pscustomobject][ordered]@{
        name = $Name
        status = $Status
        details = $Details
        log = $LogPath
    })
    $color = switch ($Status) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'Yellow' } }
    Write-Host "[$Status] $Name - $Details" -ForegroundColor $color
}

function Invoke-PowerShellGate {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $safeName = $Name -replace '[^A-Za-z0-9._-]', '-'
    $stdoutPath = Join-Path $outputRoot "$safeName.stdout.log"
    $stderrPath = Join-Path $outputRoot "$safeName.stderr.log"
    $hostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $quotedScript = '"{0}"' -f $ScriptPath
    $argumentText = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $quotedScript) + $Arguments
    try {
        $process = Start-Process -FilePath $hostPath -ArgumentList ($argumentText -join ' ') -Wait -PassThru `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Add-GateResult -Name $Name -Status PASS -Details 'Completed under Windows PowerShell 5.1.' -LogPath $stdoutPath
        }
        else {
            $errorText = if (Test-Path -LiteralPath $stderrPath) { (Get-Content -LiteralPath $stderrPath -Raw).Trim() } else { '' }
            if ([string]::IsNullOrWhiteSpace($errorText)) { $errorText = "Exited with code $($process.ExitCode)." }
            Add-GateResult -Name $Name -Status FAIL -Details $errorText -LogPath $stdoutPath
        }
    }
    catch { Add-GateResult -Name $Name -Status FAIL -Details $_.Exception.Message -LogPath $stdoutPath }
}

Write-Host 'LAZARUS KEY - WINDOWS RELEASE READINESS' -ForegroundColor Cyan
Write-Host "Version: $version  USB: $UsbRoot  Results: $outputRoot" -ForegroundColor DarkCyan
Write-Host ''

Invoke-PowerShellGate -Name 'Project syntax and metadata' -ScriptPath (Join-Path $PSScriptRoot 'Test-Project.ps1')
Invoke-PowerShellGate -Name 'Safe Report Packager regression' -ScriptPath (Join-Path $projectRoot 'tests\Test-ReportPackager.ps1')
Invoke-PowerShellGate -Name 'Portable Tools regression' -ScriptPath (Join-Path $projectRoot 'tests\Test-PortableTools.ps1')
Invoke-PowerShellGate -Name 'Case Workspace regression' -ScriptPath (Join-Path $projectRoot 'tests\Test-CaseWorkspace.ps1')
Invoke-PowerShellGate -Name 'Release engineering regression' -ScriptPath (Join-Path $projectRoot 'tests\Test-ReleaseEngineering.ps1')

$driveLetter = $UsbRoot.Substring(0, 1).ToUpperInvariant()
try {
    $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
    if ($volume.FileSystemLabel -ne 'LAZARUSKEY') {
        Add-GateResult -Name 'USB identity' -Status FAIL -Details "Expected LAZARUSKEY, found '$($volume.FileSystemLabel)'."
    }
    elseif ($volume.FileSystem -ne 'exFAT') {
        Add-GateResult -Name 'USB identity' -Status FAIL -Details "Expected exFAT, found '$($volume.FileSystem)'."
    }
    else {
        Add-GateResult -Name 'USB identity' -Status PASS -Details "LAZARUSKEY $($volume.FileSystem), $([math]::Round($volume.Size / 1GB, 2)) GiB."
    }
}
catch { Add-GateResult -Name 'USB identity' -Status FAIL -Details $_.Exception.Message }

try {
    $dataVolume = Get-Volume -ErrorAction Stop |
        Where-Object { $_.DriveLetter -and $_.FileSystemLabel -in @('LAZARUSDATA', 'LAZARUS_DATA') } |
        Select-Object -First 1
    if (-not $dataVolume) { throw 'LAZARUSDATA was not found.' }
    $freeMiB = [math]::Round($dataVolume.SizeRemaining / 1MB, 1)
    if ($freeMiB -lt 100) {
        Add-GateResult -Name 'Case-data storage' -Status FAIL -Details "Only $freeMiB MiB free on $($dataVolume.DriveLetter):."
    }
    else {
        Add-GateResult -Name 'Case-data storage' -Status PASS -Details "$($dataVolume.DriveLetter): has $freeMiB MiB free."
    }
}
catch { Add-GateResult -Name 'Case-data storage' -Status FAIL -Details $_.Exception.Message }

# A quoted argument ending in a backslash can escape its closing quote when
# Start-Process builds a Windows command line. D:\. resolves to the same drive
# root without the ambiguous trailing-backslash form.
$usbValidationRoot = "$driveLetter`:\."
Invoke-PowerShellGate -Name 'Deployed USB validation' -ScriptPath (Join-Path $PSScriptRoot 'Validate-LazarusKey.ps1') `
    -Arguments @('-Root', $usbValidationRoot)

$deployedVersionPath = Join-Path $UsbRoot 'Documentation\VERSION'
if (-not (Test-Path -LiteralPath $deployedVersionPath -PathType Leaf)) {
    Add-GateResult -Name 'Deployed version' -Status FAIL -Details 'Documentation\VERSION is missing; redeploy with -Force.'
}
else {
    $deployedVersion = (Get-Content -LiteralPath $deployedVersionPath -Raw).Trim()
    if ($deployedVersion -eq $version) {
        Add-GateResult -Name 'Deployed version' -Status PASS -Details "USB contains v$deployedVersion."
    }
    else {
        Add-GateResult -Name 'Deployed version' -Status FAIL -Details "USB has '$deployedVersion'; source is '$version'."
    }
}

$releaseBuild = $null
if (-not $SkipReleaseBuild) {
    try {
        $releaseBuild = & (Join-Path $PSScriptRoot 'Build-Release.ps1') -Version $version `
            -OutputDirectory (Join-Path $projectRoot 'release') -PassThru
        $archiveCheck = & (Join-Path $PSScriptRoot 'Test-ReleaseArchive.ps1') `
            -ArchivePath $releaseBuild.ArchivePath -HashPath $releaseBuild.HashPath -ExpectedVersion $version -PassThru
        if ($archiveCheck.Valid) {
            Add-GateResult -Name 'Release archive' -Status PASS `
                -Details "$($releaseBuild.FileCount) files; SHA-256 $($releaseBuild.Sha256)."
        }
        else { Add-GateResult -Name 'Release archive' -Status FAIL -Details ($archiveCheck.Errors -join '; ') }
    }
    catch { Add-GateResult -Name 'Release archive' -Status FAIL -Details $_.Exception.Message }
}

if ($ManualChecksPassed) {
    Add-GateResult -Name 'Manual physical checklist' -Status PASS `
        -Details 'Technician attested that docs/RELEASE-CHECKLIST-v0.5.0.md passed.'
}
else {
    Add-GateResult -Name 'Manual physical checklist' -Status PENDING `
        -Details 'Complete docs/RELEASE-CHECKLIST-v0.5.0.md, then rerun with -ManualChecksPassed.'
}

$failedCount = @($results | Where-Object status -eq 'FAIL').Count
$pendingCount = @($results | Where-Object status -eq 'PENDING').Count
$ready = ($failedCount -eq 0 -and $pendingCount -eq 0)
$report = [pscustomobject][ordered]@{
    schema_version = 1
    tool = 'lazarus-windows-release-readiness'
    version = $version
    generated_at = (Get-Date).ToString('o')
    computer = $env:COMPUTERNAME
    windows_powershell = '5.1'
    usb_root = $UsbRoot
    manual_checks_attested = [bool]$ManualChecksPassed
    ready_for_release = $ready
    failures = $failedCount
    pending = $pendingCount
    archive = if ($releaseBuild) { $releaseBuild.ArchivePath } else { $null }
    archive_sha256 = if ($releaseBuild) { $releaseBuild.Sha256 } else { $null }
    results = $results.ToArray()
}
$jsonPath = Join-Path $outputRoot 'release-readiness.json'
$textPath = Join-Path $outputRoot 'release-readiness.txt'
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
@(
    'LAZARUS KEY RELEASE READINESS'
    "Version: $version"
    "Generated: $($report.generated_at)"
    "USB: $UsbRoot"
    "Ready for release: $($ready.ToString().ToUpperInvariant())"
    ''
    ($results | ForEach-Object { '[{0}] {1} - {2}' -f $_.status, $_.name, $_.details })
) | Set-Content -LiteralPath $textPath -Encoding UTF8

Write-Host ''
if ($ready) {
    Write-Host 'READY FOR RELEASE' -ForegroundColor Green
    Write-Host "Evidence: $outputRoot" -ForegroundColor DarkCyan
    exit 0
}
if ($failedCount -gt 0) {
    Write-Host "NOT READY - $failedCount automated or USB gate(s) failed." -ForegroundColor Red
    Write-Host "Evidence: $outputRoot" -ForegroundColor DarkCyan
    exit 1
}
Write-Host 'AUTOMATED GATES PASSED - MANUAL PHYSICAL CHECKLIST REQUIRED' -ForegroundColor Yellow
Write-Host 'After completing it, rerun this command with -ManualChecksPassed.' -ForegroundColor Yellow
Write-Host "Evidence: $outputRoot" -ForegroundColor DarkCyan
exit 2
