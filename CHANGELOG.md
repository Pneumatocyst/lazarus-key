# Changelog

All notable changes to Lazarus Key will be documented here.

## [0.1.0] - 2026-08-17

### Added

- Initial GitHub-ready project scaffold.
- Branded Ventoy theme and friendly ISO aliases.
- Windows technician launcher with read-only report collection.
- Safe deployment and validation scripts.
- Pinned Hiren's BootCD PE and SystemRescue manifest.
- Architecture, Windows build, and physical test documentation.
- Automated JSON and PowerShell syntax checks.

### Verified

- Built the reference image on a nominal 8 GB Verbatim Store N Go drive using Ventoy 1.1.17 and an MBR layout.
- Validated both required ISO images against their pinned SHA-256 hashes.
- Booted the custom Lazarus Key menu and both rescue environments in UEFI mode.
- Launched the Windows technician interface and generated a complete report under `LAZARUS_DATA`.
- Documented FAT32 as the tested format for the 1 GB technician storage partition.
