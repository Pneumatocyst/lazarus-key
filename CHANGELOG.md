# Changelog

All notable changes to Lazarus Key will be documented here.

## [0.5.0] - 2026-08-18

### Added

- Added generated case workspaces with local metadata, technician notes, four-state status tracking, and an append-only activity history.
- Added active-case selection and automatic routing for built-in reports, System Info Collector, and Network Troubleshooter output.
- Added a browsable, HTML-encoded case summary with report inventory, notes, and activity.
- Added Strict case-handoff packaging through the existing redaction, manifest, checksum, and independent-verification pipeline.
- Added a graphical Case Workspace manager and a complete synthetic behavior test.
- Added a deterministic release builder, independent archive content gate, Windows PowerShell 5.1 readiness runner, physical checklist, release notes, and tag-driven publishing workflow.

### Safety

- Case folder names contain only generated identifiers rather than customer, ticket, or device values.
- Strict handoffs redact case title, ticket, customer, device, technician, and known report identifiers from copied content.
- Source reports are hashed before and after handoff packaging and remain unchanged.
- Attachments are excluded from automatic handoffs, case deletion is absent from the interface, and HTML content is encoded before display.

### Fixed

- Shortened private report-bundle staging paths and synthetic case paths to remain compatible with legacy Windows PowerShell 5.1 path-length behavior.
- Corrected deployed-drive validation in the Windows readiness runner so a root such as `D:\` cannot be corrupted by command-line quote parsing.
- Strict case handoffs now replace report directory and file names with neutral numbered names so hostnames and account identifiers cannot leak through bundle paths, manifests, or checksum listings.

### Release qualification

- Parsed all PowerShell source successfully with PowerShell 7.6.4.
- Passed the full synthetic Case Workspace behavior test, including strict handoff redaction and verification.
- Passed the Safe Report Packager and Portable Tools regression suites.
- Passed deterministic rebuild, checksum-failure, and forbidden-content release-engineering tests.
- Passed every automated Windows PowerShell 5.1, USB identity, ISO hash, storage, deployed-version, and release-archive gate.
- Passed physical Case Workspace creation, routing, notes, summaries, fallback, source immutability, Strict packaging, independent verification, and content-and-path privacy review.
- Downloaded, installed, verified, and deliberately launched Everything Search; downloaded and verified Microsoft Sysinternals Suite with pinned archive and Microsoft publisher checks.
- Confirmed the extracted source remained free of downloaded third-party archives and executables.
- Booted the themed Ventoy menu in UEFI mode, Hiren's BootCD PE, and SystemRescue, then confirmed normal internal-disk boot with the USB removed.
- Completed the final attested Windows readiness run with `READY FOR RELEASE`.

## [0.4.0] - Development milestone (not tagged)

### Added

- Added a five-tool portable catalog with pinned upstream versions, HTTPS sources, licenses, sizes, launchers, and SHA-256 hashes.
- Added a graphical Portable Tools Manager with selection, license review, installation, verification, folder access, and primary-tool launching.
- Added a command-line installer with offline archive support and a separate installed-tool verifier.
- Added synthetic offline installer tests covering license acceptance, verified installation, managed replacement, receipts, and hash-failure behavior.

### Safety

- Third-party binaries remain excluded from the repository and release packages.
- Downloads require explicit license acceptance, official HTTPS sources, exact archive sizes, and pinned SHA-256 hashes.
- ZIP paths and expected launchers are validated before an atomic-style managed-folder replacement.
- The Sysinternals Suite is downloaded directly from Microsoft because its license prohibits third-party redistribution; Microsoft publisher signatures are verified in addition to its pinned archive hash.
- Downloaded tools are never executed automatically.

### Development verification

- Parsed all PowerShell source successfully with PowerShell 7.6.4.
- Passed the synthetic offline installer and Safe Report Packager regression suites.
- Downloaded all five official upstream archives and confirmed their pinned byte sizes and SHA-256 hashes.
- Installed and verified the four non-Sysinternals archives in an isolated temporary destination.

## [0.3.0] - Development milestone (not tagged)

### Added

- Added Standard and Strict report-redaction profiles with optional custom regular expressions.
- Added safe ZIP packaging with per-file hashes, `manifest.json`, `SHA256SUMS.txt`, and a companion ZIP checksum.
- Added an independent bundle verifier for ZIP files and extracted bundles.
- Added a launcher workflow for selecting, sanitizing, reviewing, and packaging report folders.
- Added synthetic TXT, JSON, and CSV fixtures and an end-to-end PowerShell behavior test.
- Added report-privacy documentation and expanded Windows, deployment, USB, and CI validation.

### Safety

- Source reports are hashed before packaging and checked again before completion; originals are never edited.
- Manifests record redaction counts and hashes without recording the original sensitive values.
- Bundle verification rejects unsafe paths, undeclared payload files, incomplete checksum sets, and modified content.
- Generated bundles remain subject to technician review because pattern-based redaction cannot guarantee removal of every sensitive value.

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
