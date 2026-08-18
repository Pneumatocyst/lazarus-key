# Lazarus Key v0.5.0 release checklist

Complete this checklist on an authorized Windows test computer before creating the `v0.5.0` tag.

## 1. Confirm and deploy

Confirm the large Ventoy partition is really `D:` and labeled `LAZARUSKEY`. Substitute the correct letter if necessary.

```powershell
Get-Volume | Sort-Object DriveLetter | Format-Table DriveLetter,FileSystemLabel,FileSystem,Size,SizeRemaining
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\Test-Project.ps1
.\scripts\Deploy-LazarusKey.ps1 -TargetDrive D: -Force
```

Do not continue if `D:` is not the Lazarus Key.

## 2. Run automated and USB gates

```powershell
.\scripts\Test-WindowsReleaseCandidate.ps1 -UsbRoot D:\
```

Expected outcome: all automated checks pass, both ISO hashes pass, the USB reports v0.5.0, and the script says the manual physical checklist remains pending. Exit code `2` is expected at this stage.

## 3. Test the Windows launcher

- [ ] `D:\Launcher\Launch-LazarusKey.cmd` opens without an error.
- [ ] The bottom row displays **Case Workspace**, **Tool Manager**, **Reports**, and **Documentation**.
- [ ] The launcher status correctly shows standard-user or administrator state.

## 4. Test Case Workspace and routing

- [ ] Create and activate a synthetic case; do not use real sensitive information.
- [ ] Add a technician note and change its status to **In Progress**.
- [ ] Generate a built-in Support Report.
- [ ] Run System Info Collector and confirm TXT, JSON, and CSV exports.
- [ ] Run Network Troubleshooter and confirm TXT, JSON, and CSV exports.
- [ ] Confirm all three report runs appear beneath `LAZARUSDATA:\Cases\<case-id>\Reports`.
- [ ] Open the HTML summary and confirm the metadata, notes, activity, and report index render correctly.
- [ ] Create a **Strict Handoff** and confirm the ZIP plus `.sha256` file appear under the case's `Safe-Bundles` folder.
- [ ] Run the bundle verifier and confirm it passes.
- [ ] Inspect the sanitized files and confirm synthetic customer, ticket, device, technician, user, serial, and network values are absent.
- [ ] Clear the active case, generate another small report, and confirm it returns to `LAZARUSDATA:\Reports`.

## 5. Test Portable Tools Manager

- [ ] Tool Manager displays all five pinned entries.
- [ ] Install or update Everything Search after reviewing and accepting its license.
- [ ] Verify Installed reports Everything as valid.
- [ ] Launch Everything only through the deliberate **Launch Primary** action.
- [ ] Test Sysinternals separately and confirm its archive hash and Microsoft publisher checks pass.
- [ ] Confirm no downloaded ZIP or installed executable appeared inside the extracted source project.

## 6. Boot smoke test

The ISO versions and hashes are unchanged from the physically verified v0.1/v0.2 build, but perform a final smoke test for the release record.

- [ ] Ventoy opens the themed Lazarus Key menu in UEFI mode.
- [ ] Hiren's BootCD PE starts successfully.
- [ ] SystemRescue starts successfully.
- [ ] Removing the USB allows the installed operating system to boot normally.

## 7. Record release readiness

Only after every checkbox above passes:

```powershell
.\scripts\Test-WindowsReleaseCandidate.ps1 -UsbRoot D:\ -ManualChecksPassed
```

Expected final line:

```text
READY FOR RELEASE
```

Keep the generated `release\readiness-*\release-readiness.json` and TXT file with the release evidence. Do not commit the logs if they contain local computer or drive details.

## Qualification record

- Date: 2026-08-18
- Environment: authorized Windows 11 Pro x64 system, standard-user launcher context, Windows PowerShell 5.1
- Media: nominal 8 GB Verbatim Store N Go, Ventoy 1.1.17, `LAZARUSKEY` exFAT plus `LAZARUSDATA` FAT32
- Automated result: every project, regression, ISO, USB identity, storage, deployed-version, and release-archive gate passed
- Manual result: launcher, Case Workspace, report routing, Strict privacy review, portable-tool acquisition, pinned hashes, Microsoft publisher verification, UEFI Ventoy, Hiren's BootCD PE, SystemRescue, and normal internal boot passed
- Final readiness result: `READY FOR RELEASE`
- Evidence handling: readiness JSON and TXT retained locally and excluded from the repository because they contain local system details
