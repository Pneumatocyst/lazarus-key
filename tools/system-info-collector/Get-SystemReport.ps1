#Requires -Version 5.1

<#
.SYNOPSIS
    Collects a concise Windows system-information report.

.DESCRIPTION
    Displays system, hardware, memory, storage, and network information without
    changing the computer. Reports can optionally be exported as text, JSON,
    and/or CSV.

.PARAMETER ExportFormat
    One or more export formats: Text, Json, or Csv.

.PARAMETER OutputDirectory
    Directory used for exported reports. Defaults to the current directory.

.PARAMETER Quiet
    Suppresses the formatted console report. Export status messages are still shown.

.EXAMPLE
    .\Get-SystemReport.ps1

.EXAMPLE
    .\Get-SystemReport.ps1 -ExportFormat Text,Json -OutputDirectory C:\Temp
#>

[CmdletBinding()]
param(
    [ValidateSet('Text', 'Json', 'Csv')]
    [string[]]$ExportFormat = @(),

    [string]$OutputDirectory = (Get-Location).Path,

    [switch]$Quiet
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-SafeValue {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,
        $Fallback = 'Unavailable'
    )

    try {
        $value = & $Operation
        if ($null -eq $value -or ([string]$value).Trim().Length -eq 0) {
            return $Fallback
        }
        return $value
    }
    catch {
        return $Fallback
    }
}

function Format-Duration {
    param([TimeSpan]$Duration)

    $parts = @()
    if ($Duration.Days -gt 0) { $parts += ('{0}d' -f $Duration.Days) }
    if ($Duration.Hours -gt 0) { $parts += ('{0}h' -f $Duration.Hours) }
    if ($Duration.Minutes -gt 0) { $parts += ('{0}m' -f $Duration.Minutes) }
    $parts += ('{0}s' -f $Duration.Seconds)
    return ($parts -join ' ')
}

function Convert-ToDisplayText {
    param([Parameter(Mandatory = $true)]$Report)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('SYSTEM INFORMATION REPORT')
    $lines.Add(('Generated: {0}' -f $Report.CollectedAt))
    $lines.Add(('=' * 72))
    $lines.Add('')
    $lines.Add('SYSTEM')
    $lines.Add(('  Computer name : {0}' -f $Report.System.ComputerName))
    $lines.Add(('  Current user  : {0}' -f $Report.System.CurrentUser))
    $lines.Add(('  Manufacturer  : {0}' -f $Report.System.Manufacturer))
    $lines.Add(('  Model         : {0}' -f $Report.System.Model))
    $lines.Add(('  Serial number : {0}' -f $Report.System.SerialNumber))
    $lines.Add('')
    $lines.Add('OPERATING SYSTEM')
    $lines.Add(('  Name          : {0}' -f $Report.OperatingSystem.Name))
    $lines.Add(('  Version       : {0}' -f $Report.OperatingSystem.Version))
    $lines.Add(('  Architecture  : {0}' -f $Report.OperatingSystem.Architecture))
    $lines.Add(('  Last boot     : {0}' -f $Report.OperatingSystem.LastBootTime))
    $lines.Add(('  Uptime        : {0}' -f $Report.OperatingSystem.Uptime))
    $lines.Add('')
    $lines.Add('PROCESSOR AND MEMORY')
    $lines.Add(('  Processor     : {0}' -f $Report.Hardware.Processor))
    $lines.Add(('  Physical cores: {0}' -f $Report.Hardware.PhysicalCores))
    $lines.Add(('  Logical CPUs  : {0}' -f $Report.Hardware.LogicalProcessors))
    $lines.Add(('  Memory total  : {0} GB' -f $Report.Memory.TotalGB))
    $lines.Add(('  Memory free   : {0} GB' -f $Report.Memory.AvailableGB))
    $lines.Add('')
    $lines.Add('NETWORK')
    $lines.Add(('  IP addresses  : {0}' -f ($Report.Network.IPAddresses -join ', ')))
    $lines.Add(('  Gateways      : {0}' -f ($Report.Network.DefaultGateways -join ', ')))
    $lines.Add(('  DNS servers   : {0}' -f ($Report.Network.DNSServers -join ', ')))
    $lines.Add('')
    $lines.Add('STORAGE')

    foreach ($disk in $Report.Disks) {
        $lines.Add(('  {0,-8} {1,8} GB total  {2,8} GB free  {3,6}% free  {4}' -f
            $disk.Drive, $disk.TotalGB, $disk.FreeGB, $disk.FreePercent, $disk.FileSystem))
    }

    return ($lines -join [Environment]::NewLine)
}

$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
$processors = @(Get-CimInstance -ClassName Win32_Processor)
$bios = Get-CimInstance -ClassName Win32_BIOS
$logicalDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3')
$networkAdapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True')

$lastBoot = $operatingSystem.LastBootUpTime
$uptime = (Get-Date) - $lastBoot

$ipAddresses = @($networkAdapters | ForEach-Object { $_.IPAddress } | Where-Object {
    $_ -and $_ -notmatch '^127\.' -and $_ -ne '::1' -and $_ -notmatch '^fe80:'
} | Sort-Object -Unique)

$gateways = @($networkAdapters | ForEach-Object { $_.DefaultIPGateway } |
    Where-Object { $_ } | Sort-Object -Unique)

$dnsServers = @($networkAdapters | ForEach-Object { $_.DNSServerSearchOrder } |
    Where-Object { $_ } | Sort-Object -Unique)

$disks = @($logicalDisks | Sort-Object DeviceID | ForEach-Object {
    $freePercent = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
    $fileSystem = if ($_.FileSystem) { $_.FileSystem } else { 'Unavailable' }
    [pscustomobject][ordered]@{
        Drive       = $_.DeviceID
        FileSystem  = $fileSystem
        TotalGB     = [math]::Round($_.Size / 1GB, 2)
        FreeGB      = [math]::Round($_.FreeSpace / 1GB, 2)
        FreePercent = $freePercent
    }
})

$report = [pscustomobject][ordered]@{
    SchemaVersion = '1.0'
    CollectedAt   = (Get-Date).ToString('o')
    System        = [pscustomobject][ordered]@{
        ComputerName = $env:COMPUTERNAME
        CurrentUser  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Manufacturer = Get-SafeValue { $computerSystem.Manufacturer }
        Model        = Get-SafeValue { $computerSystem.Model }
        SerialNumber = Get-SafeValue { $bios.SerialNumber }
    }
    OperatingSystem = [pscustomobject][ordered]@{
        Name          = $operatingSystem.Caption
        Version       = $operatingSystem.Version
        BuildNumber   = $operatingSystem.BuildNumber
        Architecture  = $operatingSystem.OSArchitecture
        LastBootTime  = $lastBoot.ToString('o')
        Uptime        = Format-Duration -Duration $uptime
        UptimeSeconds = [math]::Floor($uptime.TotalSeconds)
    }
    Hardware       = [pscustomobject][ordered]@{
        Processor         = (($processors | ForEach-Object { $_.Name.Trim() }) -join '; ')
        PhysicalCores     = ($processors | Measure-Object -Property NumberOfCores -Sum).Sum
        LogicalProcessors = ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    }
    Memory         = [pscustomobject][ordered]@{
        TotalGB     = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        AvailableGB = [math]::Round(($operatingSystem.FreePhysicalMemory * 1KB) / 1GB, 2)
    }
    Network        = [pscustomobject][ordered]@{
        IPAddresses    = if ($ipAddresses.Count) { $ipAddresses } else { @('Unavailable') }
        DefaultGateways = if ($gateways.Count) { $gateways } else { @('Unavailable') }
        DNSServers      = if ($dnsServers.Count) { $dnsServers } else { @('Unavailable') }
    }
    Disks          = $disks
}

$displayText = Convert-ToDisplayText -Report $report
if (-not $Quiet) {
    Write-Host $displayText
}

if ($ExportFormat.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    $safeComputerName = ($report.System.ComputerName -replace '[^A-Za-z0-9._-]', '_')
    $baseName = 'system-report_{0}_{1}' -f $safeComputerName, (Get-Date -Format 'yyyyMMdd_HHmmss')

    foreach ($format in $ExportFormat | Select-Object -Unique) {
        switch ($format) {
            'Text' {
                $path = Join-Path $resolvedOutputDirectory ($baseName + '.txt')
                $displayText | Set-Content -LiteralPath $path -Encoding UTF8
            }
            'Json' {
                $path = Join-Path $resolvedOutputDirectory ($baseName + '.json')
                $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
            }
            'Csv' {
                $path = Join-Path $resolvedOutputDirectory ($baseName + '.csv')
                [pscustomobject][ordered]@{
                    CollectedAt       = $report.CollectedAt
                    ComputerName      = $report.System.ComputerName
                    CurrentUser       = $report.System.CurrentUser
                    Manufacturer      = $report.System.Manufacturer
                    Model             = $report.System.Model
                    SerialNumber      = $report.System.SerialNumber
                    OSName            = $report.OperatingSystem.Name
                    OSVersion         = $report.OperatingSystem.Version
                    OSBuild           = $report.OperatingSystem.BuildNumber
                    Architecture      = $report.OperatingSystem.Architecture
                    LastBootTime      = $report.OperatingSystem.LastBootTime
                    UptimeSeconds     = $report.OperatingSystem.UptimeSeconds
                    Processor         = $report.Hardware.Processor
                    PhysicalCores     = $report.Hardware.PhysicalCores
                    LogicalProcessors = $report.Hardware.LogicalProcessors
                    MemoryTotalGB     = $report.Memory.TotalGB
                    MemoryAvailableGB = $report.Memory.AvailableGB
                    IPAddresses       = $report.Network.IPAddresses -join '; '
                    DefaultGateways   = $report.Network.DefaultGateways -join '; '
                    DNSServers        = $report.Network.DNSServers -join '; '
                    Disks             = ($report.Disks | ForEach-Object {
                        '{0} {1}GB total/{2}GB free' -f $_.Drive, $_.TotalGB, $_.FreeGB
                    }) -join '; '
                } | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
            }
        }
        Write-Host ('Saved: {0}' -f $path) -ForegroundColor Green
    }
}
