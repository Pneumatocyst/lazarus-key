# Network Troubleshooter

> Lazarus Key integration: this tool is sourced from the companion [`it-support-toolkit`](https://github.com/Pneumatocyst/it-support-toolkit) project. Run `network-troubleshooter.ps1` from the Lazarus launcher to create TXT, JSON, and CSV exports under `LAZARUSDATA:\Reports`. The original PowerShell and Bash entry points remain available for manual use.

A read-only diagnostic utility for quickly separating local configuration,
gateway, DNS, internet, web, and TCP-port problems. It includes matching
Windows PowerShell and Linux Bash editions with clear `PASS`, `WARN`, and
`FAIL` results.

## What it checks

- Active/default network adapter
- Local IPv4 configuration
- Default gateway configuration and reachability
- Configured DNS servers
- DNS hostname resolution
- Public IP reachability using ICMP
- TCP access to DNS (53), HTTP (80), and HTTPS (443)
- A real HTTPS request and returned status code
- Optional custom `HOST:PORT` targets

The scripts do not change network settings and do not require administrator or
root access. A `WARN` does not necessarily mean the network is broken: routers,
firewalls, and websites commonly block ping or selected TCP probes.

## Result meanings

| Status | Meaning |
|---|---|
| `PASS` | The check completed successfully. |
| `WARN` | The check was inconclusive, optional, or commonly blocked. |
| `FAIL` | A core check failed and likely needs attention. |

The scripts exit with code `0` when there are no `FAIL` results, `1` when at
least one check fails, and `2` for an invalid option or export error. This makes
the tool useful both interactively and in automation.

## Windows

Requirements: Windows PowerShell 5.1 or PowerShell 7+.

Open PowerShell in this folder and run:

```powershell
.\Test-NetworkConnection.ps1
```

Test custom ports:

```powershell
.\Test-NetworkConnection.ps1 -TcpTarget 'server.example.com:22','192.168.1.50:443'
```

Export all report formats:

```powershell
.\Test-NetworkConnection.ps1 -ExportFormat Text,Json,Csv -OutputDirectory .\reports
```

If Windows blocks a downloaded script, allow it only for the current
PowerShell process:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Test-NetworkConnection.ps1
```

See built-in PowerShell help for parameters:

```powershell
Get-Help .\Test-NetworkConnection.ps1 -Detailed
```

## Linux

Requirements: Bash 4+ and common Linux networking tools. The script uses `ip`,
`ping`, `getent`, and `curl` when available. TCP checks use `nc` or Bash's
`/dev/tcp` support with `timeout`.

Make the script executable, then run it:

```bash
chmod +x network-test.sh
./network-test.sh
```

Test custom ports:

```bash
./network-test.sh --tcp server.example.com:22 --tcp 192.168.1.50:443
```

Export all report formats:

```bash
./network-test.sh --export text --export json --export csv --output-dir ./reports
```

Customize the test endpoints or timeout:

```bash
./network-test.sh \
  --dns-host example.org \
  --internet-ip 8.8.8.8 \
  --web-url https://example.org \
  --timeout 5
```

See every Linux option:

```bash
./network-test.sh --help
```

## Exported reports

Exports are timestamped and include the computer name:

```text
network-report_COMPUTERNAME_20260807_120000.txt
network-report_COMPUTERNAME_20260807_120000.json
network-report_COMPUTERNAME_20260807_120000.csv
```

Generated reports are excluded by the repository's `.gitignore` rules.

## Interpreting common combinations

| Results | Likely cause |
|---|---|
| No IPv4 address | Disconnected adapter, DHCP issue, or adapter configuration problem |
| Gateway fails but local IPv4 passes | Local router, VLAN, Wi-Fi, or LAN connectivity issue |
| Public IP passes but DNS fails | DNS server or DNS configuration problem |
| DNS passes but HTTPS fails | Proxy, firewall, TLS, captive portal, or upstream web issue |
| Ping warns but HTTPS passes | ICMP is probably blocked; normal browsing is working |
| Only a custom port fails | Target service is stopped, filtered, or listening on another port |

## Privacy and responsible use

Reports can contain the computer name, local IP address, gateway, DNS servers,
and custom targets. Review them before sharing publicly. Only test custom hosts
and ports that you own or are authorized to troubleshoot.

## Files

```text
network-troubleshooter/
├── Test-NetworkConnection.ps1
├── network-test.sh
└── README.md
```
