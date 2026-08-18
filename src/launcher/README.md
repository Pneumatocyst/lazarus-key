# Lazarus Key launcher

Run `Launch-LazarusKey.cmd` from Windows. The launcher uses Windows PowerShell and WPF already included with supported Windows desktop releases.

The built-in actions are read-only:

- Generate Support Report
- Network Snapshot
- Storage Snapshot
- Microsoft System Information
- Device Manager
- Event Viewer

The three technician-tool buttons are active:

```text
Scripts/System-Info-Collector/system-info.ps1
Scripts/Network-Troubleshooter/network-troubleshooter.ps1
Scripts/Report-Packager/report-packager.ps1
```

Reports are written to `LAZARUSDATA:\Reports` when that volume is available. Otherwise the launcher creates a local `Reports` directory on the main Lazarus Key volume.

The bottom **Case Workspace** button opens `Scripts/Case-Workspace/case-workspace.ps1`. When a case is active, built-in reports and both integrated technician tools automatically route into that case. The manager tracks notes, status, activity, an HTML summary, and Strict sanitized handoffs.

Each tool creates a timestamped subfolder and exports TXT, JSON, and CSV reports. The Windows wrappers open the completed folder automatically and keep their console open so the technician can review the result summary.

Package Reports asks the technician to select one report folder and choose Standard or Strict sanitization. It writes a new ZIP and checksum under `Reports\Safe-Bundles` without modifying the source reports.

The bottom **Tool Manager** button opens `Scripts/Portable-Tools/portable-tools-manager.ps1`. It can download, verify, install, inspect, and deliberately launch cataloged optional tools. Third-party binaries are not part of the Lazarus Key source or release package.

Matching Bash editions are included beside the Windows scripts for manual use from Linux rescue environments:

```text
Scripts/System-Info-Collector/system-report.sh
Scripts/Network-Troubleshooter/network-test.sh
```
