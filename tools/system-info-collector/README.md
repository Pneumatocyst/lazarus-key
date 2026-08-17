# System Info Collector

> Lazarus Key integration: this tool is sourced from the companion [`it-support-toolkit`](https://github.com/Pneumatocyst/it-support-toolkit) project. Run `system-info.ps1` from the Lazarus launcher to create TXT, JSON, and CSV exports under `LAZARUSDATA:\Reports`. The original PowerShell and Bash entry points remain available for manual use.

A small, read-only troubleshooting utility that collects useful system,
hardware, storage, and network details. The project includes matching Windows
PowerShell and Linux Bash editions.

## What it collects

- Computer name and current user
- Manufacturer, model, and serial number
- Operating system, version, architecture, boot time, and uptime
- Processor, physical cores, logical processors, and memory
- Local disk capacity and free space
- IP addresses, default gateway, and DNS servers

The scripts do not install software, change settings, or require administrator
or root access. Some firmware information may display as `Unavailable` when the
current account or virtual-machine platform does not expose it.

## Windows

Requirements: Windows PowerShell 5.1 or PowerShell 7+.

Open PowerShell in the project directory and run:

```powershell
.\Get-SystemReport.ps1
```

Export one or more formats:

```powershell
.\Get-SystemReport.ps1 -ExportFormat Text,Json,Csv -OutputDirectory .\reports
```

If Windows blocks a downloaded script, use this for the current PowerShell
process only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Get-SystemReport.ps1
```

## Linux

Requirements: Bash 4+, plus common Linux utilities such as `df`, `awk`, and
`hostname`. The script uses `lscpu` and `ip` when available and falls back
gracefully when they are missing.

Make the script executable, then run it:

```bash
chmod +x system-report.sh
./system-report.sh
```

Export one or more formats:

```bash
./system-report.sh --export text --export json --export csv --output-dir ./reports
```

See all options:

```bash
./system-report.sh --help
```

## Report filenames

Exports use the computer name and collection time so reports from multiple
machines do not overwrite one another:

```text
system-report_COMPUTERNAME_20260807_103000.json
```

## Privacy note

Reports may contain a device serial number, username, local IP addresses, DNS
servers, and storage layout. Review a report and remove sensitive fields before
posting it publicly or attaching it to a public GitHub issue.

## Suggested repository layout

```text
system-info-collector/
├── Get-SystemReport.ps1
├── system-report.sh
└── README.md
```

## Possible next improvements

- Add a `--redact` / `-Redact` privacy option
- Add automated PowerShell Pester and Bash smoke tests
- Add optional HTML output
- Flag low disk space and low available memory
- Combine this collector with future network and service diagnostics
