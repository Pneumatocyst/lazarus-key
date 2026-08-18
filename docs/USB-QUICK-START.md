# Lazarus Key quick start

## Boot recovery environments

1. Insert the Lazarus Key while the computer is powered off.
2. Start the computer and open its one-time boot menu, commonly with F9, F10, F11, F12, or Esc.
3. Select the USB device.
4. Choose a recovery environment from the Lazarus Key menu.

Use Hiren's BootCD PE for Windows-focused repair and SystemRescue for Linux filesystems, partitioning, imaging, networking, and lower-level recovery.

## Use from running Windows

Open the main Lazarus Key volume, then run:

```text
Launcher\Launch-LazarusKey.cmd
```

The launcher can create read-only system, network, storage, and recent-event reports. The System Info Collector and Network Troubleshooter buttons also export timestamped TXT, JSON, and CSV bundles and open the completed report folder automatically.

Use **Case Workspace** before collecting reports for a ticketed support session. Create and activate the case, run diagnostics, add notes, update its status, and open the HTML summary. New reports route into the active case until **Clear Active** is selected.

Use **Package Reports** before sending diagnostics outside the support team. Select one report folder, choose Strict or Standard redaction, review the sanitized output, and share only the new ZIP from `Reports\Safe-Bundles`. The original report folder is not modified.

Use **Tool Manager** to select optional utilities. Review the displayed upstream licenses, confirm the official-source download, and run **Verify Installed** before launching a tool. Sysinternals is intentionally not selected by default because it is the largest download and its license prohibits Lazarus Key from redistributing it.

From a Linux rescue environment, mount the main Lazarus Key partition and run the matching Bash tools with `bash`:

```bash
bash Scripts/System-Info-Collector/system-report.sh --export text --export json --export csv --output-dir /path/to/reports
bash Scripts/Network-Troubleshooter/network-test.sh --export text --export json --export csv --output-dir /path/to/reports
```

## Storage

Use `LAZARUSDATA` for reports, drivers, technician notes, and explicitly recovered files. Do not store passwords, private keys, BitLocker recovery keys, or unencrypted sensitive records on the Lazarus Key.

Sanitization is pattern-based and may miss unexpected sensitive values. Always inspect the sanitized TXT, JSON, and CSV files before sharing the ZIP.

## Before making changes

- Confirm you are authorized to service the computer.
- Identify the internal disk by model, serial number, and capacity.
- Back up important data when possible.
- Read every partitioning, imaging, erase, and restore confirmation carefully.
- Never assume `/dev/sda`, Disk 0, or the first listed disk is the intended target.
- A verified download is not automatically safe to use on the wrong disk. Read every third-party recovery or write confirmation.
