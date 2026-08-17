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
| UEFI, Secure Boot enabled | Pending | Pending | Pending |
| UEFI, Secure Boot disabled | Pending | Pending | Pending |
| Legacy BIOS/CSM | Pending | Pending | Pending |

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
