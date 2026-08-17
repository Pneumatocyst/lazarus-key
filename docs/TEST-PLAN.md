# Lazarus Key test plan

Record each result with the date, computer model, firmware mode, Ventoy version, and ISO versions.

## Project validation

| Test | Expected result |
| --- | --- |
| Parse `ventoy.json` | Valid JSON |
| Parse `images.json` | Valid JSON |
| PowerShell syntax | No parser errors |
| Required project files | All present |
| ISO hashes | Match pinned SHA-256 values |

## Windows launcher

| Test | Standard user | Administrator |
| --- | --- | --- |
| Launcher opens | Required | Required |
| System report completes | Required; limitations allowed | Required |
| Network snapshot completes | Required | Required |
| Storage snapshot completes | Required; limitations allowed | Required |
| Reports use `LAZARUS_DATA` | Required when mounted | Required when mounted |
| Missing optional script message | Clear and non-fatal | Clear and non-fatal |

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
- Storage partition: `LAZARUS_DATA`, FAT32, approximately 1 GB
- ISO validation: Hiren's BootCD PE x64 1.0.8 and SystemRescue 13.02 amd64 passed their pinned SHA-256 checks
- Windows launcher: opened successfully as a standard user
- Report collection: completed and wrote `system.txt`, `storage.txt`, `network.txt`, and `events.txt` under `LAZARUS_DATA:\Reports`
- Boot menu: custom Lazarus Key theme, keyboard navigation, and friendly Linux/Windows aliases verified
- Rescue environments: both required images launched successfully
- Host computer model: not recorded

## Functional checks

- Theme renders at 1024x768 without clipped text.
- Keyboard navigation and Enter work.
- The local internal disk is visible but remains unmodified.
- `LAZARUS_DATA` and the main Lazarus Key partition are visible where supported.
- Wired networking is detected in both rescue environments.
- Shutdown and reboot return control cleanly to firmware.
- Removing the USB allows the installed operating system to boot normally.

## Release gate

A version may be labeled stable only after:

1. All automated project checks pass.
2. Both required ISO hashes pass.
3. At least one UEFI physical boot test passes for each ISO.
4. The launcher creates and opens reports correctly.
5. No reports, recovered data, ISO images, or third-party binaries are present in the release package.
