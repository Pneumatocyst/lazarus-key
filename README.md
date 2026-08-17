# Lazarus Key

Lazarus Key is a compact, Ventoy-based troubleshooting and recovery USB designed for an 8 GB flash drive. It combines a polished boot menu, a Windows technician launcher, bootable recovery environments, portable utilities, and a separate place for reports and recovered files.

> Status: v0.1.0 starter scaffold. The project files are ready; third-party ISO images and portable applications must be downloaded separately from their official sources.

## What v0.1 includes

- A dark Lazarus Key Ventoy theme and friendly boot-menu names.
- A Windows PowerShell/WPF technician launcher.
- Read-only system, storage, and network report collection.
- Ventoy deployment and validation scripts.
- A pinned ISO manifest with official URLs and SHA-256 hashes.
- A safe public-repository layout that does not redistribute third-party binaries.
- GitHub Actions validation for JSON and PowerShell syntax.

## Recommended 8 GB loadout

| Image | Role | Approximate size |
| --- | --- | ---: |
| Hiren's BootCD PE x64 1.0.8 | Windows repair and diagnostics | 3.06 GB |
| SystemRescue 13.02 amd64 | Linux recovery, partitioning, imaging, and memory testing | 1,318 MiB |

The two core images use roughly 4.4 GiB. An 8 GB flash drive normally exposes about 7.45 GiB, leaving room for Ventoy, the launcher, portable tools, and approximately 1 GB of technician storage.

## Proposed disk layout

| Partition | Format | Suggested size | Purpose |
| --- | --- | ---: | --- |
| `LAZARUSKEY` | exFAT | Remaining space | Ventoy, ISOs, launcher, and portable tools |
| `VTOYEFI` | FAT | Created by Ventoy | Boot files; do not modify |
| `LAZARUS_DATA` | exFAT | 1,024 MB | Reports, drivers, notes, and recovered files |

Use Ventoy's reserved-space option during its initial installation to leave 1,024 MB at the end of the drive. Create `LAZARUS_DATA` in that reserved space afterward.

## Repository layout

```text
lazarus-key/
├── .github/workflows/validate.yml
├── config/ventoy/                 Ventoy menu and theme
├── docs/                          Architecture, build, and test guides
├── manifests/images.json          Pinned ISO sources and hashes
├── scripts/                       Deployment and validation scripts
├── src/launcher/                  Windows launcher source
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

See [`docs/BUILD-WINDOWS.md`](docs/BUILD-WINDOWS.md) for the complete procedure.

## Safety model

- The launcher defaults to read-only collection and built-in management consoles.
- Disk partitioning, imaging, password recovery, and data recovery tools live inside third-party rescue environments and require deliberate selection.
- The deployment script never formats or repartitions a disk.
- Always confirm the target disk before installing Ventoy or changing partitions.
- Use this toolkit only on systems you own or are authorized to support.

## Third-party downloads

This repository does not include Ventoy, Hiren's BootCD PE, SystemRescue, or portable application binaries. Download them from their official project sites and verify their hashes using the supplied validator.

- [Ventoy](https://www.ventoy.net/en/download.html)
- [Hiren's BootCD PE](https://www.hirensbootcd.org/download/)
- [SystemRescue](https://www.system-rescue.org/Download/)

## Roadmap

- v0.1: project scaffold, launcher, theme, manifest, and validation
- v0.2: integrate the existing system-info collector and network troubleshooter
- v0.3: add signed report bundles and automatic redaction
- v0.4: add optional portable-tool acquisition manifests
- v1.0: physical BIOS/UEFI test matrix and reproducible release package

## License

Original project code and documentation are licensed under the MIT License. Third-party tools retain their own licenses.
