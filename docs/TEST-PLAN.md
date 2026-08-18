# Lazarus Key test plan

Record each result with the date, computer model, firmware mode, Ventoy version, and ISO versions.

## Project validation

| Test | Expected result |
| --- | --- |
| Parse `ventoy.json` | Valid JSON |
| Parse `images.json` | Valid JSON |
| Parse and validate `portable-tools.json` | Valid JSON and five valid catalog entries |
| PowerShell syntax | No parser errors |
| Required project files | All present |
| ISO hashes | Match pinned SHA-256 values |
| Deterministic release rebuild | Unchanged source produces the same ZIP SHA-256 |
| Release archive content gate | Rejects binaries, ISOs, reports, cases, unsafe paths, missing files, and bad checksums |

## Windows launcher

| Test | Standard user | Administrator |
| --- | --- | --- |
| Launcher opens | Required | Required |
| System report completes | Required; limitations allowed | Required |
| Network snapshot completes | Required | Required |
| Storage snapshot completes | Required; limitations allowed | Required |
| Reports use `LAZARUSDATA` | Required when mounted | Required when mounted |
| System Info Collector exports TXT/JSON/CSV | Required | Required |
| Network Troubleshooter exports TXT/JSON/CSV | Required | Required |
| Package Reports creates ZIP and checksum | Required | Required |
| Standard and Strict profiles complete | Required | Required |
| Source report hashes remain unchanged | Required | Required |
| Bundle verifier passes | Required | Required |
| Tool results open automatically | Required | Required |
| Missing technician tool message | Clear and non-fatal | Clear and non-fatal |
| Report fallback without `LAZARUSDATA` | Required | Required |
| Tool Manager opens and displays five entries | Required | Required |
| License confirmation precedes download | Required | Required |
| Default tool download and hash verification | Required | Required |
| Installed-tool verification and deliberate launch | Required | Required |
| Create and activate a case | Required | Required |
| Built-in and integrated reports route to active case | Required | Required |
| Notes, status, activity, and HTML summary update | Required | Required |
| Strict case handoff verifies and removes case identity | Required | Required |
| Clearing active case restores normal report routing | Required | Required |

Inspect reports for accidental secrets before sharing them.

## Physical boot matrix

| Firmware configuration | Ventoy menu | Hiren PE | SystemRescue |
| --- | --- | --- | --- |
| UEFI, physical v0.1.0 test (Secure Boot state not recorded) | Pass - 2026-08-17 | Pass - 2026-08-17 | Pass - 2026-08-17 |
| UEFI, Secure Boot enabled | Pending | Pending | Pending |
| UEFI, Secure Boot disabled | Pending | Pending | Pending |
| Legacy BIOS/CSM | Pending | Pending | Pending |

### v0.1.0 verified build record

- USB: Verbatim Store N Go, nominal 8 GB (7.47 GB visible)
- Ventoy: 1.1.17, MBR layout, UEFI boot
- Main partition: `LAZARUSKEY`, exFAT, approximately 6.44 GB
- Storage partition: `LAZARUSDATA`, FAT32, approximately 1 GB
- ISO validation: Hiren's BootCD PE x64 1.0.8 and SystemRescue 13.02 amd64 passed their pinned SHA-256 checks
- Windows launcher: opened successfully as a standard user
- Report collection: completed and wrote `system.txt`, `storage.txt`, `network.txt`, and `events.txt` under `LAZARUSDATA:\Reports`
- Boot menu: custom Lazarus Key theme, keyboard navigation, and friendly Linux/Windows aliases verified
- Rescue environments: both required images launched successfully
- Host computer model: not recorded

### v0.2.0 technician-tools verification

- Date: 2026-08-17
- Host: authorized Windows 11 Pro x64 test system
- User context: standard user; some collections may be limited as designed
- Project validation: all JSON and PowerShell checks passed
- USB validation: both pinned ISO hashes passed with zero warnings
- System Info Collector: generated and opened TXT, JSON, and CSV exports successfully
- Network Troubleshooter: completed 11 checks with 11 PASS, 0 WARN, and 0 FAIL
- Report routing: timestamped tool folders and all three formats were written under `LAZARUSDATA:\Reports`
- Windows PowerShell compatibility: JSON serialization verified after the v0.2.0 release-candidate fix

### v0.3.0 safe-report verification

- Automated synthetic fixture test: passed under PowerShell 7.6.4 and Windows PowerShell 5.1 on 2026-08-18
- Physical USB deployment: passed on the qualified v0.5.0 build
- Strict profile and case handoff: passed content, neutral-path, valid-JSON, checksum, and independent-verification checks
- Source-file immutability: passed before-and-after SHA-256 comparison
- ZIP, companion checksum, manifest, and per-file hash verification: passed
- Manual privacy review: passed after RC3 neutralized report directory and file names

### v0.4.0 portable-tools verification

- PowerShell parser: all project scripts passed under PowerShell 7.6.4 and Windows PowerShell 5.1 on 2026-08-18
- Synthetic offline catalog and installer test: passed under PowerShell 7.6.4 and Windows PowerShell 5.1
- Safe Report Packager regression test: passed under PowerShell 7.6.4
- Official archive acquisition: all five upstream archives downloaded and matched the pinned sizes and SHA-256 hashes on 2026-08-18
- Real archive staging: Everything, Notepad++, TestDisk/PhotoRec, and CrystalDiskInfo installed and verified in an isolated temporary destination
- Sysinternals archive structure, expected launchers, pinned archive hash, and Microsoft Authenticode publisher verification: passed
- Graphical manager on Windows PowerShell 5.1: passed with all five catalog entries displayed
- Official Windows download and redirect handling: passed for Everything Search and Microsoft Sysinternals Suite
- Free-space checks: implemented for destination and temporary storage; qualified USB had sufficient capacity
- License confirmation: passed for Everything Search and Microsoft Sysinternals Suite
- SHA-256 mismatch rejection: passed synthetic fail-closed test
- Install, installed-state verification, deliberate launch, and managed update: passed
- Release archive and extracted-source binary-exclusion checks: passed

### v0.5.0 case-workspace verification

- Synthetic create, activate, route, note, status, summary, package, verify, immutability, and path-safety test: passed under PowerShell 7.6.4 on 2026-08-18
- Initial Windows PowerShell 5.1 readiness run exposed legacy path-length behavior; shortened transient paths passed in RC2 and RC3
- Windows GUI behavior: passed as a standard user
- Built-in launcher report routing: passed into the active case
- Integrated System Info and Network Troubleshooter routing: passed with TXT, JSON, and CSV exports
- Strict case-identity redaction, neutral report paths, and original-report immutability: passed in RC3
- Clear-active fallback to the normal Reports directory: passed
- Deterministic build, bad-checksum rejection, and forbidden-report rejection: passed under PowerShell 7.6.4 on 2026-08-18
- RC3 passed all automated Windows readiness gates, the complete physical checklist, and the final `-ManualChecksPassed` attestation with `READY FOR RELEASE`

## Functional checks

- Theme renders at 1024x768 without clipped text.
- Keyboard navigation and Enter work.
- The local internal disk is visible but remains unmodified.
- `LAZARUSDATA` and the main Lazarus Key partition are visible where supported.
- Wired networking is detected in both rescue environments.
- Shutdown and reboot return control cleanly to firmware.
- Removing the USB allows the installed operating system to boot normally.

## Technician tools

- System Info Collector reports include system identity, OS, CPU, memory, storage, and network data.
- Network Troubleshooter displays clear PASS, WARN, and FAIL results.
- Network failures are reported without changing adapter, DNS, proxy, or firewall settings.
- Each Windows tool creates a unique timestamped report directory.
- TXT, JSON, and CSV exports open successfully and contain no parser errors.
- Reports are reviewed for usernames, serial numbers, IP addresses, DNS servers, and other sensitive details before sharing.
- Safe Report Packager preserves valid JSON and produces readable TXT and CSV output.
- The sanitized bundle contains `manifest.json` and `SHA256SUMS.txt`.
- The ZIP companion checksum and independent verifier both pass.
- Original report hashes remain identical before and after packaging.
- Strict redaction removes all known sensitive values from the synthetic fixture.
- Portable Tools Catalog rejects duplicate ids, unsafe paths, non-HTTPS URLs, incomplete licenses, and malformed hashes.
- Portable tool installation requires license acceptance and exact archive size and SHA-256 values.
- Case folder names contain only generated IDs, and active-case selection never changes existing report content.
- Strict case handoffs remove synthetic case-specific values, verify successfully, and preserve source report hashes.
- Managed updates use staging and do not execute downloaded content automatically.
- Bash editions pass `bash -n` syntax validation and show help successfully when run with `--help`.

## Release gate

A version may be labeled stable only after:

1. All automated project checks pass.
2. Both required ISO hashes pass.
3. At least one UEFI physical boot test passes for each ISO.
4. The launcher creates and opens reports correctly.
5. No reports, recovered data, ISO images, or third-party binaries are present in the release package.
6. Safe-report source immutability, JSON validity, redaction, and hash verification tests pass.
7. Portable-tools catalog, offline installer, real download, publisher, launch, update, and binary-exclusion tests pass.
8. Case creation, routing, notes, summary, Strict handoff, verification, and fallback tests pass.
9. `Test-WindowsReleaseCandidate.ps1` reports `READY FOR RELEASE` with retained evidence.
10. The `vX.Y.Z` tag exactly matches `VERSION`; tag automation rebuilds, verifies, and publishes the ZIP plus checksum.
