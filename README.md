# Lazarus Key

Lazarus Key is a compact, Ventoy-based troubleshooting and recovery USB designed for an 8 GB flash drive. It combines a polished boot menu, a Windows technician launcher, bootable recovery environments, portable utilities, and a separate place for reports and recovered files.

> Status: v0.5.0 is physically qualified for release. The cumulative report-packaging, portable-tool management, Case Workspace, and release-engineering workflows passed the Windows PowerShell 5.1, privacy, publisher, USB, and physical boot gates on 2026-08-18.

## What v0.5 includes

- A dark Lazarus Key Ventoy theme and friendly boot-menu names.
- A Windows PowerShell/WPF technician launcher.
- Read-only system, storage, and network report collection.
- Integrated Windows and Linux system-information collectors.
- Integrated Windows and Linux network troubleshooters with PASS/WARN/FAIL results.
- Standard and Strict report-redaction profiles with safe ZIP packaging and integrity manifests.
- An independent verifier for sanitized report bundles.
- A license-aware Portable Tools Manager with official-source downloads and fail-closed verification.
- A pinned five-tool catalog for Everything, Notepad++, TestDisk/PhotoRec, CrystalDiskInfo, and Microsoft Sysinternals Suite.
- A Case Workspace that groups reports, notes, status, activity, and handoff bundles beneath a generated case ID.
- Automatic report routing into the active case with a clear return to the original non-case workflow.
- A browsable HTML case summary and Strict sanitized case-handoff packaging.
- Ventoy deployment and validation scripts.
- A pinned ISO manifest with official URLs and SHA-256 hashes.
- A safe public-repository layout that does not redistribute third-party binaries.
- GitHub Actions validation for JSON and PowerShell syntax.
- A deterministic release builder, fail-closed archive verifier, Windows PowerShell 5.1 readiness report, and tag-driven GitHub publisher.

## Recommended 8 GB loadout

| Image | Role | Approximate size |
| --- | --- | ---: |
| Hiren's BootCD PE x64 1.0.8 | Windows repair and diagnostics | 3.06 GB |
| SystemRescue 13.02 amd64 | Linux recovery, partitioning, imaging, and memory testing | 1,318 MiB |

The two core images use roughly 4.4 GiB. The four default portable tools require approximately 124 MiB after extraction; adding the optional Sysinternals Suite brings the full catalog to approximately 396 MiB. An 8 GB flash drive normally exposes about 7.45 GiB, leaving sufficient room for this catalog, Ventoy, the launcher, and approximately 1 GB of technician storage.

## Tested 8 GB disk layout

| Partition | Format | Suggested size | Purpose |
| --- | --- | ---: | --- |
| `LAZARUSKEY` | exFAT | Remaining space | Ventoy, ISOs, launcher, and portable tools |
| `VTOYEFI` | FAT | Created by Ventoy | Boot files; do not modify |
| `LAZARUSDATA` | FAT32 | 1,024 MB | Reports, drivers, notes, and recovered files |

Use Ventoy's reserved-space option during its initial installation to leave 1,024 MB at the end of the drive. Create `LAZARUSDATA` in that reserved space afterward. FAT volume labels are limited to 11 characters, so the underscore form is not used for the physical partition.

The reference physical build uses Ventoy 1.1.17 on a nominal 8 GB Verbatim Store N Go drive. The themed menu booted in UEFI mode, both pinned ISO hashes passed, Hiren's BootCD PE and SystemRescue launched successfully, and the Windows launcher wrote its reports to `LAZARUSDATA`. In v0.2.0, both integrated technician tools generated TXT, JSON, and CSV exports successfully. Secure Boot enrollment behavior and Legacy BIOS/CSM remain part of the broader compatibility matrix.

## Repository layout

```text
lazarus-key/
├── .github/workflows/validate.yml
├── config/ventoy/                 Ventoy menu and theme
├── docs/                          Architecture, build, and test guides
├── manifests/images.json          Pinned ISO sources and hashes
├── manifests/portable-tools.json  Optional tool sources, licenses, sizes, and hashes
├── scripts/                       Deployment and validation scripts
├── src/launcher/                  Windows launcher source
├── tools/                         Integrated Windows and Linux technician tools
├── CHANGELOG.md
├── LICENSE
└── VERSION
```

## Quick start

1. Back up the flash drive. Installing Ventoy erases it.
2. Install the current Ventoy release using MBR and reserve 1,024 MB.
3. Open an elevated Windows PowerShell prompt in this project directory.
4. Deploy the project content:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\scripts\Deploy-LazarusKey.ps1 -TargetDrive E:
   ```

5. Download the two ISO files listed in [`manifests/images.json`](manifests/images.json) and place them at their exact destination paths.
6. Validate the finished drive:

   ```powershell
   .\scripts\Validate-LazarusKey.ps1 -Root E:
   ```

7. Boot-test the drive on an authorized test computer.

The launcher’s System Info Collector and Network Troubleshooter buttons create timestamped TXT, JSON, and CSV report bundles under `LAZARUSDATA:\Reports`. When a Case Workspace is active, built-in and integrated reports instead route to that case's `Reports` directory. The Package Reports button creates sanitized copies under `LAZARUSDATA:\Reports\Safe-Bundles`; originals are never edited. If the data partition is unavailable, the tools safely fall back to the main Lazarus Key volume.

Sanitized bundles contain a redaction manifest, per-file SHA-256 hashes, and a companion checksum for the ZIP. Pattern-based sanitization reduces accidental disclosure risk but does not replace technician review. See [`docs/REPORT-PRIVACY.md`](docs/REPORT-PRIVACY.md).

The launcher’s **Tool Manager** downloads optional utilities directly from their publishers, checks free space, verifies exact size and SHA-256 values, and installs them under `PortableTools`. It never executes a download automatically. See [`docs/PORTABLE-TOOLS.md`](docs/PORTABLE-TOOLS.md).

The launcher’s **Case Workspace** creates a local support case, routes new reports into it, records technician notes and status, builds an HTML index, and packages a Strict redacted handoff. See [`docs/CASE-WORKSPACE.md`](docs/CASE-WORKSPACE.md).

See [`docs/BUILD-WINDOWS.md`](docs/BUILD-WINDOWS.md) for the complete procedure.

The v0.5.0 qualification procedure is recorded in [`docs/RELEASE-CHECKLIST-v0.5.0.md`](docs/RELEASE-CHECKLIST-v0.5.0.md). The Windows readiness runner combines all automated regressions, deployed USB validation, ISO hashes, data-partition capacity, project version matching, release-archive verification, and an explicit manual-checklist attestation.

```powershell
.\scripts\Test-WindowsReleaseCandidate.ps1 -UsbRoot D:\
```

## Safety model

- The launcher defaults to read-only collection and built-in management consoles.
- Disk partitioning, imaging, password recovery, and data recovery tools live inside third-party rescue environments and require deliberate selection.
- The deployment script never formats or repartitions a disk.
- Always confirm the target disk before installing Ventoy or changing partitions.
- Use this toolkit only on systems you own or are authorized to support.

## Third-party downloads

This repository does not include Ventoy, Hiren's BootCD PE, SystemRescue, or portable application binaries. ISO images are obtained manually; the Portable Tools Manager obtains optional utilities directly from their cataloged upstream sources.

- [Ventoy](https://www.ventoy.net/en/download.html)
- [Hiren's BootCD PE](https://www.hirensbootcd.org/download/)
- [SystemRescue](https://www.system-rescue.org/Download/)

## Roadmap

- v0.1: project scaffold, launcher, theme, manifest, and validation
- v0.2: integrated system-info collector and network troubleshooter
- v0.3: privacy-safe report bundles, automatic redaction, and integrity verification
- v0.4: verified portable-tools catalog and acquisition manager
- v0.5: case workspace, report index, and technician handoff workflow
- v0.6: storage dashboard, capacity forecasting, and case retention tools
- v1.0: physical BIOS/UEFI test matrix and reproducible release package

## License

Original project code and documentation are licensed under the MIT License. Third-party tools retain their own licenses.
