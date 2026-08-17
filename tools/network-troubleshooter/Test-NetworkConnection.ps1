#requires -version 5.1

[CmdletBinding()]
param(
    [ValidateSet('Text', 'Json', 'Csv')]
    [string[]]$ExportFormat = @(),

    [string]$OutputDirectory = (Get-Location).Path,

    [ValidateRange(1, 120)]
    [int]$TimeoutSeconds = 3,

    [ValidateNotNullOrEmpty()]
    [string]$DnsHost = 'example.com',

    [ValidateNotNullOrEmpty()]
    [string]$InternetIp = '1.1.1.1',

    [ValidateNotNullOrEmpty()]
    [string]$WebUrl = 'https://example.com',

    [string[]]$TcpTarget = @(),

    [switch]$Quiet,

    [switch]$Version,

    [switch]$NoExit
)

$ScriptVersion = '1.0.0'

if ($Version) {
    Write-Output $ScriptVersion
    exit 0
}

$Results = New-Object System.Collections.Generic.List[object]

function Add-DiagnosticResult {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Check,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Details,
        [AllowNull()][Nullable[long]]$LatencyMs
    )

    $Results.Add([pscustomobject][ordered]@{
        Category  = $Category
        Check     = $Check
        Target    = $Target
        Status    = $Status
        Details   = $Details
        LatencyMs = $LatencyMs
    })
}

function Invoke-PingCheck {
    param([Parameter(Mandatory = $true)][string]$HostName)

    $ping = $null
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send($HostName, ($TimeoutSeconds * 1000))
        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            return [pscustomobject]@{
                Success   = $true
                LatencyMs = [long]$reply.RoundtripTime
                Details   = 'Target replied to ICMP'
            }
        }
        return [pscustomobject]@{
            Success   = $false
            LatencyMs = $null
            Details   = "No ICMP reply ($($reply.Status))"
        }
    }
    catch {
        return [pscustomobject]@{
            Success   = $false
            LatencyMs = $null
            Details   = "Ping failed: $($_.Exception.Message)"
        }
    }
    finally {
        if ($null -ne $ping) { $ping.Dispose() }
    }
}

function Invoke-TcpCheck {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][int]$Port
    )

    $client = $null
    $waitHandle = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
        $waitHandle = $asyncResult.AsyncWaitHandle
        if (-not $waitHandle.WaitOne(($TimeoutSeconds * 1000), $false)) {
            return [pscustomobject]@{
                Success   = $false
                LatencyMs = [long]$stopwatch.ElapsedMilliseconds
                Details   = 'TCP connection timed out'
            }
        }
        $client.EndConnect($asyncResult)
        return [pscustomobject]@{
            Success   = $true
            LatencyMs = [long]$stopwatch.ElapsedMilliseconds
            Details   = 'TCP connection succeeded'
        }
    }
    catch {
        return [pscustomobject]@{
            Success   = $false
            LatencyMs = [long]$stopwatch.ElapsedMilliseconds
            Details   = "TCP connection failed: $($_.Exception.Message)"
        }
    }
    finally {
        $stopwatch.Stop()
        if ($null -ne $waitHandle) { $waitHandle.Close() }
        if ($null -ne $client) { $client.Close() }
    }
}

function Add-TcpDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Check,
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][int]$Port,
        [Parameter(Mandatory = $true)][ValidateSet('WARN', 'FAIL')][string]$FailureStatus
    )

    $tcp = Invoke-TcpCheck -HostName $HostName -Port $Port
    $status = if ($tcp.Success) { 'PASS' } else { $FailureStatus }
    Add-DiagnosticResult -Category $Category -Check $Check -Target "${HostName}:$Port" `
        -Status $status -Details $tcp.Details -LatencyMs $tcp.LatencyMs
}

try {
    [System.Uri]$webUri = $WebUrl
    if ($webUri.Scheme -notin @('http', 'https') -or [string]::IsNullOrWhiteSpace($webUri.Host)) {
        throw 'The URL must use HTTP or HTTPS and contain a hostname.'
    }
}
catch {
    Write-Error "Invalid WebUrl '$WebUrl': $($_.Exception.Message)"
    exit 2
}

$parsedCustomTargets = New-Object System.Collections.Generic.List[object]
foreach ($entry in $TcpTarget) {
    if ($entry -notmatch '^\[?(.+)\]?:(\d+)$') {
        Write-Error "Invalid TcpTarget '$entry'; expected HOST:PORT."
        exit 2
    }
    $targetHost = $Matches[1].Trim([char[]]'[]')
    $targetPort = 0
    if (-not [int]::TryParse($Matches[2], [ref]$targetPort) -or $targetPort -lt 1 -or $targetPort -gt 65535) {
        Write-Error "Invalid TCP port in '$entry'; use a value from 1 through 65535."
        exit 2
    }
    $parsedCustomTargets.Add([pscustomobject]@{ Host = $targetHost; Port = $targetPort })
}

$generatedAt = (Get-Date).ToString('o')
$computerName = $env:COMPUTERNAME
if ([string]::IsNullOrWhiteSpace($computerName)) {
    $computerName = [System.Net.Dns]::GetHostName()
}

$activeConfig = $null
$adapterName = 'local system'
$localAddresses = @()
$gateway = $null
$dnsServers = @()

try {
    $configurations = @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object {
        $_.NetAdapter.Status -eq 'Up' -and $null -ne $_.IPv4Address
    })
    $activeConfig = $configurations | Where-Object { $null -ne $_.IPv4DefaultGateway } | Select-Object -First 1
    if ($null -eq $activeConfig) { $activeConfig = $configurations | Select-Object -First 1 }

    if ($null -ne $activeConfig) {
        $adapterName = [string]$activeConfig.InterfaceAlias
        $localAddresses = @($activeConfig.IPv4Address | ForEach-Object { $_.IPAddress })
        if ($null -ne $activeConfig.IPv4DefaultGateway) {
            $gateway = [string]$activeConfig.IPv4DefaultGateway.NextHop
        }
        try {
            $dnsServers = @((Get-DnsClientServerAddress -InterfaceIndex $activeConfig.InterfaceIndex `
                -AddressFamily IPv4 -ErrorAction Stop).ServerAddresses | Where-Object { $_ })
        }
        catch {
            $dnsServers = @()
        }
    }
}
catch {
    try {
        $legacyConfig = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction Stop |
            Where-Object { $_.IPEnabled -and $_.IPAddress } | Select-Object -First 1
        if ($null -ne $legacyConfig) {
            $adapterName = [string]$legacyConfig.Description
            $localAddresses = @($legacyConfig.IPAddress | Where-Object { $_ -match '^\d+\.' })
            $gateway = @($legacyConfig.DefaultIPGateway | Where-Object { $_ -match '^\d+\.' }) | Select-Object -First 1
            $dnsServers = @($legacyConfig.DNSServerSearchOrder | Where-Object { $_ })
        }
    }
    catch {
        # The results below explain that configuration discovery failed.
    }
}

if ($localAddresses.Count -gt 0) {
    Add-DiagnosticResult -Category 'Local network' -Check 'Active adapter' -Target $adapterName `
        -Status 'PASS' -Details 'Adapter has an IPv4 configuration' -LatencyMs $null
    Add-DiagnosticResult -Category 'Local network' -Check 'IPv4 configuration' -Target $adapterName `
        -Status 'PASS' -Details ($localAddresses -join ' ') -LatencyMs $null
}
else {
    Add-DiagnosticResult -Category 'Local network' -Check 'Active adapter' -Target $adapterName `
        -Status 'FAIL' -Details 'No active IPv4 adapter was detected' -LatencyMs $null
    Add-DiagnosticResult -Category 'Local network' -Check 'IPv4 configuration' -Target $adapterName `
        -Status 'FAIL' -Details 'No IPv4 address was detected' -LatencyMs $null
}

if (-not [string]::IsNullOrWhiteSpace($gateway)) {
    Add-DiagnosticResult -Category 'Local network' -Check 'Default gateway' -Target $gateway `
        -Status 'PASS' -Details 'A default IPv4 gateway is configured' -LatencyMs $null
    $gatewayPing = Invoke-PingCheck -HostName $gateway
    Add-DiagnosticResult -Category 'Local network' -Check 'Gateway reachability' -Target $gateway `
        -Status $(if ($gatewayPing.Success) { 'PASS' } else { 'WARN' }) `
        -Details $(if ($gatewayPing.Success) { 'Gateway replied to ICMP' } else { "$($gatewayPing.Details); the gateway may block ping" }) `
        -LatencyMs $gatewayPing.LatencyMs
}
else {
    Add-DiagnosticResult -Category 'Local network' -Check 'Default gateway' -Target 'local routing table' `
        -Status 'WARN' -Details 'No IPv4 default gateway was detected' -LatencyMs $null
    Add-DiagnosticResult -Category 'Local network' -Check 'Gateway reachability' -Target 'not available' `
        -Status 'WARN' -Details 'Skipped because no gateway was detected' -LatencyMs $null
}

if ($dnsServers.Count -gt 0) {
    Add-DiagnosticResult -Category 'DNS' -Check 'DNS configuration' -Target 'resolver' `
        -Status 'PASS' -Details ($dnsServers -join ' ') -LatencyMs $null
}
else {
    Add-DiagnosticResult -Category 'DNS' -Check 'DNS configuration' -Target 'resolver' `
        -Status 'WARN' -Details 'No IPv4 DNS server was detected for the active adapter' -LatencyMs $null
}

$dnsStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $resolved = @([System.Net.Dns]::GetHostAddresses($DnsHost) | ForEach-Object { $_.IPAddressToString } |
        Select-Object -Unique)
    $dnsStopwatch.Stop()
    if ($resolved.Count -gt 0) {
        Add-DiagnosticResult -Category 'DNS' -Check 'Hostname resolution' -Target $DnsHost `
            -Status 'PASS' -Details ($resolved -join ' ') -LatencyMs ([long]$dnsStopwatch.ElapsedMilliseconds)
    }
    else {
        Add-DiagnosticResult -Category 'DNS' -Check 'Hostname resolution' -Target $DnsHost `
            -Status 'FAIL' -Details 'Hostname did not resolve' -LatencyMs ([long]$dnsStopwatch.ElapsedMilliseconds)
    }
}
catch {
    $dnsStopwatch.Stop()
    Add-DiagnosticResult -Category 'DNS' -Check 'Hostname resolution' -Target $DnsHost `
        -Status 'FAIL' -Details "DNS lookup failed: $($_.Exception.Message)" `
        -LatencyMs ([long]$dnsStopwatch.ElapsedMilliseconds)
}

$internetPing = Invoke-PingCheck -HostName $InternetIp
Add-DiagnosticResult -Category 'Internet' -Check 'Public IP reachability' -Target $InternetIp `
    -Status $(if ($internetPing.Success) { 'PASS' } else { 'WARN' }) `
    -Details $(if ($internetPing.Success) { 'Public IP replied to ICMP' } else { "$($internetPing.Details); some networks block ping" }) `
    -LatencyMs $internetPing.LatencyMs

Add-TcpDiagnostic -Category 'Ports' -Check 'HTTP port' -HostName $webUri.Host -Port 80 -FailureStatus 'WARN'
Add-TcpDiagnostic -Category 'Ports' -Check 'HTTPS port' -HostName $webUri.Host -Port 443 -FailureStatus 'FAIL'

if ($dnsServers.Count -gt 0) {
    Add-TcpDiagnostic -Category 'Ports' -Check 'DNS TCP port' -HostName $dnsServers[0] -Port 53 -FailureStatus 'WARN'
}
else {
    Add-DiagnosticResult -Category 'Ports' -Check 'DNS TCP port' -Target 'not available' `
        -Status 'WARN' -Details 'Skipped because no DNS server was detected' -LatencyMs $null
}

$webStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $response = Invoke-WebRequest -Uri $webUri.AbsoluteUri -Method Get -UseBasicParsing `
        -TimeoutSec $TimeoutSeconds -ErrorAction Stop
    $webStopwatch.Stop()
    Add-DiagnosticResult -Category 'Internet' -Check 'Web request' -Target $webUri.AbsoluteUri `
        -Status 'PASS' -Details "HTTP status $([int]$response.StatusCode)" `
        -LatencyMs ([long]$webStopwatch.ElapsedMilliseconds)
}
catch {
    $webStopwatch.Stop()
    Add-DiagnosticResult -Category 'Internet' -Check 'Web request' -Target $webUri.AbsoluteUri `
        -Status 'FAIL' -Details "HTTPS request failed: $($_.Exception.Message)" `
        -LatencyMs ([long]$webStopwatch.ElapsedMilliseconds)
}

foreach ($custom in $parsedCustomTargets) {
    Add-TcpDiagnostic -Category 'Custom' -Check 'Custom TCP port' -HostName $custom.Host `
        -Port $custom.Port -FailureStatus 'FAIL'
}

$passCount = @($Results | Where-Object Status -eq 'PASS').Count
$warnCount = @($Results | Where-Object Status -eq 'WARN').Count
$failCount = @($Results | Where-Object Status -eq 'FAIL').Count

if (-not $Quiet) {
    Write-Host 'NETWORK TROUBLESHOOTER'
    Write-Host "Computer: $computerName | Generated: $generatedAt"
    Write-Host ''
    foreach ($result in $Results) {
        $color = switch ($result.Status) {
            'PASS' { 'Green' }
            'WARN' { 'Yellow' }
            'FAIL' { 'Red' }
        }
        $latencyText = if ($null -ne $result.LatencyMs) { " | $($result.LatencyMs) ms" } else { '' }
        Write-Host ("[{0,-4}]" -f $result.Status) -ForegroundColor $color -NoNewline
        Write-Host (" {0,-24} | {1,-22} | {2}{3}" -f $result.Check, $result.Target, $result.Details, $latencyText)
    }
    Write-Host ''
    Write-Host "Summary: $passCount PASS, $warnCount WARN, $failCount FAIL"
}

if ($ExportFormat.Count -gt 0) {
    try {
        if (-not (Test-Path -LiteralPath $OutputDirectory)) {
            $null = New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop
        }
        $resolvedOutput = (Resolve-Path -LiteralPath $OutputDirectory -ErrorAction Stop).Path
    }
    catch {
        Write-Error "Could not create or access output directory '$OutputDirectory': $($_.Exception.Message)"
        exit 2
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $safeName = $computerName -replace '[^A-Za-z0-9._-]', ''
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = 'unknown-host' }

    foreach ($format in ($ExportFormat | Select-Object -Unique)) {
        switch ($format.ToLowerInvariant()) {
            'text' {
                $path = Join-Path $resolvedOutput "network-report_${safeName}_${timestamp}.txt"
                $lines = New-Object System.Collections.Generic.List[string]
                $lines.Add('NETWORK TROUBLESHOOTER REPORT')
                $lines.Add("Computer: $computerName")
                $lines.Add("Generated: $generatedAt")
                $lines.Add("Summary: $passCount PASS, $warnCount WARN, $failCount FAIL")
                $lines.Add(('=' * 96))
                $lines.Add(($Results | Format-Table Status, Category, Check, Target, Details, LatencyMs -AutoSize |
                    Out-String -Width 240).TrimEnd())
                $lines | Out-File -LiteralPath $path -Encoding UTF8
                Write-Host "Saved TEXT report: $path"
            }
            'json' {
                $path = Join-Path $resolvedOutput "network-report_${safeName}_${timestamp}.json"
                # Materialize the generic list before constructing the payload.
                # Windows PowerShell 5.1 can throw "Argument types do not match"
                # when the conversion expression is embedded in a PSCustomObject.
                [object[]]$jsonResults = $Results.ToArray()
                [pscustomobject][ordered]@{
                    tool          = 'network-troubleshooter'
                    version       = $ScriptVersion
                    computer_name = $computerName
                    generated_at  = $generatedAt
                    summary       = [pscustomobject]@{ pass = $passCount; warn = $warnCount; fail = $failCount }
                    results       = $jsonResults
                } | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $path -Encoding UTF8
                Write-Host "Saved JSON report: $path"
            }
            'csv' {
                $path = Join-Path $resolvedOutput "network-report_${safeName}_${timestamp}.csv"
                $Results | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
                Write-Host "Saved CSV report: $path"
            }
        }
    }
}

if ($NoExit) {
    return [pscustomobject][ordered]@{
        Pass = $passCount
        Warn = $warnCount
        Fail = $failCount
    }
}

if ($failCount -gt 0) { exit 1 }
exit 0
