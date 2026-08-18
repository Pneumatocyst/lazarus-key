# Build Lazarus Key on Windows

## Requirements

- One 8 GB or larger USB flash drive.
- A Windows computer with administrator rights.
- The latest Ventoy Windows package.
- The Lazarus Key project files.
- Internet access for obtaining third-party images.

## 1. Identify and back up the USB

Copy everything important off the flash drive. Open Disk Management and record the disk number, capacity, and current drive letter. Disconnect unnecessary removable drives to reduce mistakes.

## 2. Install Ventoy

1. Download Ventoy from its official site and verify its published checksum.
2. Extract the package and run `Ventoy2Disk.exe` as administrator.
3. Select the 8 GB flash drive by capacity and device name.
4. Under **Option > Partition Style**, select **MBR** for broad legacy BIOS and UEFI compatibility.
5. Under **Option > Partition Configuration**, reserve **1024 MB** at the end of the disk.
6. Leave Secure Boot support enabled unless testing identifies a compatibility issue.
7. Select **Install**, read the destructive warnings, and re-check the target before confirming.

Ventoy installation is the only destructive part of this build.

## 3. Create LAZARUSDATA

Use Disk Management to create a new simple volume in the 1,024 MB unallocated space:

- Label: `LAZARUSDATA` (the 11-character FAT volume-label limit excludes the underscore form)
- Filesystem: FAT32 (tested) or exFAT
- Allocation unit: Default

Windows Disk Management may offer FAT32 rather than exFAT for this 1 GB volume. FAT32 is the tested v0.1.0 configuration and is appropriate here because the partition cannot hold a file larger than FAT32's per-file limit anyway.

Create these folders:

```text
LAZARUSDATA:\Drivers
LAZARUSDATA:\Reports
LAZARUSDATA:\Cases
LAZARUSDATA:\Recovered-Files
LAZARUSDATA:\Technician-Notes
```

## 4. Deploy Lazarus Key project content

Open an elevated Windows PowerShell prompt in the project directory:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Deploy-LazarusKey.ps1 -TargetDrive E:
```

Replace `E:` with the large Ventoy data partition's actual drive letter. The deployment script only copies project files; it never formats or partitions the drive.

## 5. Add the ISO images

Download each image from the official page listed in `manifests/images.json`.

Place them at exactly:

```text
LAZARUSKEY:\ISO\Windows\HBCD_PE_x64.iso
LAZARUSKEY:\ISO\Linux\systemrescue-13.02-amd64.iso
```

Do not rename the files unless you also update both `ventoy.json` and the manifest.

## 6. Validate

```powershell
.\scripts\Validate-LazarusKey.ps1 -Root E:
```

The validator checks project files, parses the Ventoy configuration, verifies the theme target, locates required images, and validates their SHA-256 hashes.

## 7. Launch inside Windows

Open:

```text
E:\Launcher\Launch-LazarusKey.cmd
```

Generate a sample support report and confirm that it is written to `LAZARUSDATA:\Reports` when that partition is mounted.

Test the **System Info Collector** and **Network Troubleshooter** buttons. Each should:

1. Open a PowerShell console.
2. Create a timestamped subfolder under `LAZARUSDATA:\Reports`.
3. Export TXT, JSON, and CSV files.
4. Open the completed folder in File Explorer.
5. Keep the console open until Enter is pressed.

If `LAZARUSDATA` is unavailable, confirm that the tools fall back to `LAZARUSKEY:\Reports` without failing.

Test **Package Reports** with a newly generated report folder:

1. Select the report folder in the folder picker.
2. Choose **Strict** redaction.
3. Confirm a ZIP and companion `.sha256` file appear under `LAZARUSDATA:\Reports\Safe-Bundles`.
4. Extract the ZIP and open `manifest.json`, `SHA256SUMS.txt`, and each sanitized report.
5. Confirm the original report hashes are unchanged.
6. Run `Scripts\Report-Packager\Test-SafeReportBundle.ps1 -BundlePath <zip>` and confirm verification passes.
7. Review the sanitized content manually before sharing it.

Test **Tool Manager** without installing everything at once:

1. Open Tool Manager and inspect each tool's source, version, size, license, and SHA-256 value.
2. Install the small default **Everything Search** entry first.
3. Confirm the manager downloads from the cataloged official URL and reports a successful verified installation.
4. Select Everything and use **Launch Primary**; confirm it opens only after deliberate selection.
5. Use **Verify Installed** and confirm Everything is `Valid` while unselected tools are `NotInstalled`.
6. Re-run installation, decline the replacement prompt, and confirm the current folder remains unchanged.
7. Re-run and approve replacement; confirm the managed update succeeds and verifies.
8. Install the remaining defaults only if the USB has enough free space.
9. Test Sysinternals separately. Confirm its archive hash and Microsoft publisher-signature checks pass.
10. Confirm no downloaded ZIP, EXE, installed tool directory, or installation receipt exists in the source checkout or release ZIP.

Pinned hashes intentionally fail when an upstream publisher replaces an archive. Treat a mismatch as a catalog-maintenance event, not as permission to bypass verification.

Test **Case Workspace**:

1. Create a case with a synthetic ticket, customer, and device name; confirm it becomes active.
2. Run a built-in Support Report, System Info Collector, and Network Troubleshooter.
3. Confirm every new output folder appears beneath the active case's `Reports` directory.
4. Add a note, move the status to In Progress, and open the HTML summary.
5. Confirm metadata and report filenames render correctly and HTML-sensitive characters are escaped.
6. Create a Strict handoff and verify its ZIP with `Scripts\Report-Packager\Test-SafeReportBundle.ps1`.
7. Confirm case title, ticket, customer, device, technician, host, user, serial, and network identities are absent from the sanitized content.
8. Confirm original report hashes remain unchanged.
9. Clear the active case and confirm the next report returns to the normal `Reports` directory.

## 8. Boot-test

Follow `TEST-PLAN.md`. At minimum, confirm the themed menu, Hiren's BootCD PE, SystemRescue, keyboard input, storage visibility, network hardware, and a clean return to the local operating system.

## v0.1.0 reference build

The first physically verified build used:

- Verbatim Store N Go USB drive, nominal 8 GB (7.47 GB visible in Windows)
- Ventoy 1.1.17, MBR partition style
- `LAZARUSKEY`: exFAT, approximately 6.44 GB
- `VTOYEFI`: FAT, 32 MB, created by Ventoy
- `LAZARUSDATA`: FAT32, approximately 1 GB
- UEFI boot mode
- Hiren's BootCD PE x64 1.0.8 and SystemRescue 13.02 amd64

Both ISO files passed the pinned SHA-256 validation before boot testing. The custom Ventoy theme, both rescue environments, Windows launcher, and report output to `LAZARUSDATA` were verified successfully.

## Release qualification

For v0.5.0 and later, use the versioned release checklist and the combined Windows gate after deployment:

```powershell
.\scripts\Test-WindowsReleaseCandidate.ps1 -UsbRoot E:\
```

Complete the GUI and boot checks in `docs\RELEASE-CHECKLIST-v0.5.0.md`, then rerun with `-ManualChecksPassed`. Do not create the release tag until the final output is `READY FOR RELEASE`.
