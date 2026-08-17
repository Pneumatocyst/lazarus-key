# Changelog

All notable changes to Lazarus Key will be documented here.

## [0.2.0] - 2026-08-17

### Added

- Integrated the Windows System Info Collector with TXT, JSON, and CSV exports.
- Integrated the Windows Network Troubleshooter with layered PASS, WARN, and FAIL diagnostics.
- Added Linux Bash editions of both technician tools for manual use from rescue environments.
- Added Lazarus-specific wrappers that create timestamped report folders and open completed results.
- Added automatic report routing to `LAZARUSDATA`, with a safe fallback to the main USB partition.
- Expanded project, deployment, USB, and GitHub Actions validation for the technician tools.

### Changed

- Activated the System Info Collector and Network Troubleshooter launcher buttons.
- Updated the project version and ISO manifest metadata to 0.2.0.

### Fixed

- Made Network Troubleshooter JSON export compatible with Windows PowerShell 5.1.
- Corrected data-partition detection for the FAT-compatible `LAZARUSDATA` label while retaining support for the legacy underscore form.
- Added a CIM fallback for report-volume discovery when the Storage module cannot resolve the data partition.

### Verified

- Passed all project syntax checks and both pinned ISO hash validations with zero warnings.
- Generated TXT, JSON, and CSV bundles with the Windows System Info Collector.
- Completed 11 Network Troubleshooter checks with 11 PASS, 0 WARN, and 0 FAIL.
- Routed both technician tools to timestamped folders under `LAZARUSDATA:\Reports`.
- Confirmed successful operation from the deployed USB as a standard Windows user.

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
- Launched the Windows technician interface and generated a complete report under `LAZARUSDATA`.
- Documented FAT32 as the tested format for the 1 GB technician storage partition.
