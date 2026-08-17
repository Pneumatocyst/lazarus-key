# Lazarus Key launcher

Run `Launch-LazarusKey.cmd` from Windows. The launcher uses Windows PowerShell and WPF already included with supported Windows desktop releases.

The built-in actions are read-only:

- Generate Support Report
- Network Snapshot
- Storage Snapshot
- Microsoft System Information
- Device Manager
- Event Viewer

The two technician-tool buttons are active in v0.2.0:

```text
Scripts/System-Info-Collector/system-info.ps1
Scripts/Network-Troubleshooter/network-troubleshooter.ps1
```

Reports are written to `LAZARUSDATA:\Reports` when that volume is available. Otherwise the launcher creates a local `Reports` directory on the main Lazarus Key volume.

Each tool creates a timestamped subfolder and exports TXT, JSON, and CSV reports. The Windows wrappers open the completed folder automatically and keep their console open so the technician can review the result summary.

Matching Bash editions are included beside the Windows scripts for manual use from Linux rescue environments:

```text
Scripts/System-Info-Collector/system-report.sh
Scripts/Network-Troubleshooter/network-test.sh
```
