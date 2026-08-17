# Lazarus Key launcher

Run `Launch-LazarusKey.cmd` from Windows. The launcher uses Windows PowerShell and WPF already included with supported Windows desktop releases.

The built-in actions are read-only:

- Generate Support Report
- Network Snapshot
- Storage Snapshot
- Microsoft System Information
- Device Manager
- Event Viewer

The two Lazarus Key script buttons are integration points. They activate automatically when these files are present on the USB:

```text
Scripts/System-Info-Collector/system-info.ps1
Scripts/Network-Troubleshooter/network-troubleshooter.ps1
```

Reports are written to `LAZARUS_DATA:\Reports` when that volume is available. Otherwise the launcher creates a local `Reports` directory on the main Lazarus Key volume.
