[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

$script:BasePath = Split-Path -Parent $PSScriptRoot
$script:ReportsPath = Join-Path $script:BasePath 'Reports'
$script:StatusText = $null

function Resolve-ReportsPath {
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
        # Use the local fallback below.
    }

    # Use the local fallback when the data partition is absent.
    return (Join-Path $script:BasePath 'Reports')
}

function Set-Status {
    param([Parameter(Mandatory)][string]$Message)
    if ($script:StatusText) {
        $script:StatusText.Text = $Message
    }
}

function Open-PathSafe {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    Start-Process explorer.exe -ArgumentList $Path
}

function New-ReportDirectory {
    $script:ReportsPath = Resolve-ReportsPath
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $computer = $env:COMPUTERNAME -replace '[^A-Za-z0-9_-]', '_'
    $path = Join-Path $script:ReportsPath "$computer-$stamp"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Write-CommandOutput {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][scriptblock]$Command
    )

    "Lazarus Key - $Title" | Set-Content -LiteralPath $FilePath -Encoding UTF8
    "Generated: $(Get-Date -Format o)" | Add-Content -LiteralPath $FilePath -Encoding UTF8
    ('=' * 72) | Add-Content -LiteralPath $FilePath -Encoding UTF8
    try {
        & $Command 2>&1 | Out-String -Width 240 | Add-Content -LiteralPath $FilePath -Encoding UTF8
    }
    catch {
        "Collection error: $($_.Exception.Message)" | Add-Content -LiteralPath $FilePath -Encoding UTF8
    }
}

function New-SystemReport {
    Set-Status 'Collecting system information...'
    $output = New-ReportDirectory

    Write-CommandOutput -FilePath (Join-Path $output 'system.txt') -Title 'System Information' -Command {
        Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber,
            CsManufacturer, CsModel, CsSystemType, CsProcessors, CsTotalPhysicalMemory,
            BiosManufacturer, BiosSMBIOSBIOSVersion, BiosReleaseDate
    }

    Write-CommandOutput -FilePath (Join-Path $output 'storage.txt') -Title 'Storage Snapshot' -Command {
        Get-Disk | Format-Table Number, FriendlyName, SerialNumber, HealthStatus, OperationalStatus,
            PartitionStyle, @{Name='SizeGB'; Expression={[math]::Round($_.Size / 1GB, 2)}} -AutoSize
        Get-PhysicalDisk | Format-Table FriendlyName, MediaType, HealthStatus, OperationalStatus,
            @{Name='SizeGB'; Expression={[math]::Round($_.Size / 1GB, 2)}} -AutoSize
        Get-Volume | Format-Table DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
            @{Name='SizeGB'; Expression={[math]::Round($_.Size / 1GB, 2)}},
            @{Name='FreeGB'; Expression={[math]::Round($_.SizeRemaining / 1GB, 2)}} -AutoSize
    }

    Write-CommandOutput -FilePath (Join-Path $output 'network.txt') -Title 'Network Snapshot' -Command {
        Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, LinkSpeed, MacAddress -AutoSize
        Get-NetIPConfiguration | Format-List
        Get-DnsClientServerAddress | Format-Table InterfaceAlias, AddressFamily, ServerAddresses -AutoSize
        route.exe print
    }

    Write-CommandOutput -FilePath (Join-Path $output 'events.txt') -Title 'Recent Critical and Error Events' -Command {
        Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
            Select-Object -First 100 TimeCreated, Id, ProviderName, LevelDisplayName, Message |
            Format-List
    }

    Set-Status "Report saved: $output"
    [System.Windows.MessageBox]::Show("Read-only support report created at:`n$output", 'Lazarus Key') | Out-Null
    Open-PathSafe -Path $output
}

function New-NetworkSnapshot {
    Set-Status 'Collecting network snapshot...'
    $output = New-ReportDirectory
    $file = Join-Path $output 'network-diagnostics.txt'
    Write-CommandOutput -FilePath $file -Title 'Network Diagnostics' -Command {
        ipconfig.exe /all
        "`n--- ROUTES ---"
        route.exe print
        "`n--- DNS TEST ---"
        Resolve-DnsName example.com -ErrorAction Continue
        "`n--- DEFAULT GATEWAY TEST ---"
        $gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric | Select-Object -First 1 -ExpandProperty NextHop)
        if ($gateway) { Test-Connection -ComputerName $gateway -Count 2 -ErrorAction Continue }
        "`n--- INTERNET IP TEST ---"
        Test-Connection -ComputerName 1.1.1.1 -Count 2 -ErrorAction Continue
    }
    Set-Status "Network snapshot saved: $file"
    Open-PathSafe -Path $output
}

function New-StorageSnapshot {
    Set-Status 'Collecting storage snapshot...'
    $output = New-ReportDirectory
    $file = Join-Path $output 'storage-diagnostics.txt'
    Write-CommandOutput -FilePath $file -Title 'Storage Diagnostics' -Command {
        Get-Disk | Format-List Number, FriendlyName, SerialNumber, FirmwareVersion, HealthStatus,
            OperationalStatus, PartitionStyle, IsBoot, IsSystem, Size
        Get-PhysicalDisk | Format-List FriendlyName, UniqueId, MediaType, BusType, HealthStatus,
            OperationalStatus, CannotPoolReason, Size
        Get-Volume | Format-List DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
            OperationalStatus, Size, SizeRemaining
    }
    Set-Status "Storage snapshot saved: $file"
    Open-PathSafe -Path $output
}

function Start-OptionalScript {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$DisplayName
    )
    $path = Join-Path $script:BasePath $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        [System.Windows.MessageBox]::Show(
            "$DisplayName has not been added yet.`n`nExpected path:`n$path",
            'Technician tool missing',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
        return
    }
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path)
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Lazarus Key" Width="1040" Height="700"
        WindowStartupLocation="CenterScreen" Background="#090B12" Foreground="#F2F4F7"
        FontFamily="Segoe UI" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#1D2033"/>
      <Setter Property="Foreground" Value="#F2F4F7"/>
      <Setter Property="BorderBrush" Value="#34384F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="18"/>
      <Setter Property="Margin" Value="7"/>
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#2A2450"/>
                <Setter Property="BorderBrush" Value="#8B7CFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="28">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="7,0,7,20">
      <TextBlock Text="LAZARUS KEY" FontSize="30" FontWeight="SemiBold"/>
      <TextBlock Text="AUTHORIZED DIAGNOSTICS AND RECOVERY" Foreground="#8B7CFF" FontSize="13" Margin="0,5,0,0"/>
    </StackPanel>

    <Border Grid.Row="1" Background="#131624" CornerRadius="8" Padding="14" Margin="7,0,7,12">
      <TextBlock Text="Read-only collection is the default. Review third-party recovery actions before applying changes."
                 Foreground="#B7BBC8" TextWrapping="Wrap"/>
    </Border>

    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Button x:Name="SystemReport" Grid.Row="0" Grid.Column="0" Content="Generate Support Report&#x0a;System, storage, network, events"/>
      <Button x:Name="NetworkSnapshot" Grid.Row="0" Grid.Column="1" Content="Network Snapshot&#x0a;Adapters, IP, DNS, routes, tests"/>
      <Button x:Name="StorageSnapshot" Grid.Row="0" Grid.Column="2" Content="Storage Snapshot&#x0a;Disks, volumes, and health state"/>
      <Button x:Name="SystemInfo" Grid.Row="1" Grid.Column="0" Content="System Information&#x0a;Open Microsoft System Information"/>
      <Button x:Name="DeviceManager" Grid.Row="1" Grid.Column="1" Content="Device Manager&#x0a;Inspect hardware and drivers"/>
      <Button x:Name="EventViewer" Grid.Row="1" Grid.Column="2" Content="Event Viewer&#x0a;Inspect Windows event logs"/>
      <Button x:Name="SystemCollector" Grid.Row="2" Grid.Column="0" Content="System Info Collector&#x0a;Export hardware, OS, storage, and network details"/>
      <Button x:Name="NetworkTool" Grid.Row="2" Grid.Column="1" Content="Network Troubleshooter&#x0a;Run layered PASS, WARN, and FAIL diagnostics"/>
      <Button x:Name="OpenTools" Grid.Row="2" Grid.Column="2" Content="Portable Tools&#x0a;Open the portable utilities folder"/>
    </Grid>

    <Grid Grid.Row="3" Margin="7,14,7,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock x:Name="StatusText" Grid.Column="0" Text="Ready" Foreground="#98A2B3" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
      <Button x:Name="OpenReports" Grid.Column="1" Content="Reports" Padding="18,8" Margin="6,0"/>
      <Button x:Name="OpenDocs" Grid.Column="2" Content="Documentation" Padding="18,8" Margin="6,0,0,0"/>
    </Grid>
  </Grid>
</Window>
'@

$reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$script:StatusText = $window.FindName('StatusText')
$script:ReportsPath = Resolve-ReportsPath

$window.FindName('SystemReport').Add_Click({ New-SystemReport })
$window.FindName('NetworkSnapshot').Add_Click({ New-NetworkSnapshot })
$window.FindName('StorageSnapshot').Add_Click({ New-StorageSnapshot })
$window.FindName('SystemInfo').Add_Click({ Start-Process msinfo32.exe })
$window.FindName('DeviceManager').Add_Click({ Start-Process devmgmt.msc })
$window.FindName('EventViewer').Add_Click({ Start-Process eventvwr.msc })
$window.FindName('SystemCollector').Add_Click({
    Start-OptionalScript -RelativePath 'Scripts\System-Info-Collector\system-info.ps1' -DisplayName 'System Info Collector'
})
$window.FindName('NetworkTool').Add_Click({
    Start-OptionalScript -RelativePath 'Scripts\Network-Troubleshooter\network-troubleshooter.ps1' -DisplayName 'Network Troubleshooter'
})
$window.FindName('OpenTools').Add_Click({ Open-PathSafe -Path (Join-Path $script:BasePath 'PortableTools') })
$window.FindName('OpenReports').Add_Click({ Open-PathSafe -Path $script:ReportsPath })
$window.FindName('OpenDocs').Add_Click({ Open-PathSafe -Path (Join-Path $script:BasePath 'Documentation') })

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
$adminStatus = if ($admin) {
    'Ready - running as administrator'
}
else {
    'Ready - standard user; some collections may be limited'
}
Set-Status -Message $adminStatus

$window.ShowDialog() | Out-Null
