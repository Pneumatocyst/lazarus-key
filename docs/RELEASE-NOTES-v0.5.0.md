# Lazarus Key v0.5.0

Lazarus Key v0.5.0 is the first cumulative feature release after v0.2.0. It promotes the privacy-safe reporting work developed for v0.3, the verified portable-tool acquisition work developed for v0.4, and the new v0.5 Case Workspace as one physically qualified release.

## Highlights

- Standard and Strict report redaction with sanitized ZIPs, manifests, per-file hashes, and independent verification.
- A license-aware Portable Tools Manager with five pinned official-source tools.
- Generated case workspaces with active report routing, notes, status, activity history, and HTML summaries.
- Strict case handoffs that remove case-specific and diagnostic identifiers from both content and report paths while preserving source reports.
- A reproducible release builder, fail-closed archive verifier, Windows PowerShell 5.1 readiness gate, and automated tag publisher.

## Portable tools catalog

- Everything Search 1.4.1.1032 x64
- Notepad++ Portable 8.9.6.1 x64
- TestDisk/PhotoRec 7.2 win64
- CrystalDiskInfo 9.9.1 x64
- Microsoft Sysinternals Suite 2026.07

Third-party binaries and ISO images are not included. The manager downloads optional tools from their cataloged upstream sources only after license review, then checks exact size, SHA-256, archive paths, expected launchers, and applicable publisher signatures.

## Release qualification

The v0.5.0 build passed the complete Windows PowerShell 5.1 readiness suite and an authorized physical test on 2026-08-18. Qualification covered both pinned ISO hashes, the Windows launcher, active-case routing and fallback, TXT/JSON/CSV exports, Strict content-and-path privacy review, bundle verification, Everything Search installation and launch, Microsoft Sysinternals archive and publisher validation, UEFI Ventoy, Hiren's BootCD PE, SystemRescue, and normal internal-disk boot after USB removal.

Secure Boot enrollment behavior and Legacy BIOS/CSM remain outside this release's qualified matrix.

## Upgrade an existing Lazarus Key

Back up any reports or cases you want to retain, extract this release, and run from an elevated Windows PowerShell prompt:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\Test-Project.ps1
.\scripts\Deploy-LazarusKey.ps1 -TargetDrive D: -Force
.\scripts\Validate-LazarusKey.ps1 -Root D:\
```

Replace `D:` with the confirmed `LAZARUSKEY` drive letter. Deployment updates project-managed files only; it does not format, repartition, remove ISOs, or delete existing case/report data.

## Verification

Download both the ZIP and its companion `.sha256` file. Verify before extraction:

```powershell
Get-FileHash .\Lazarus_Key_v0.5.0.zip -Algorithm SHA256
Get-Content .\Lazarus_Key_v0.5.0.zip.sha256
```

The values must match exactly. Run `scripts\Test-ReleaseArchive.ps1` after extraction when an additional structural check is desired.

## Safety

Use Lazarus Key only on systems you own or are authorized to service. Read-only diagnostics remain the default. Pattern-based redaction reduces disclosure risk but cannot guarantee removal of every sensitive value; manually review every handoff before sharing it.
