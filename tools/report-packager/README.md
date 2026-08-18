# Safe Report Packager

The Safe Report Packager creates a sanitized copy of an existing Lazarus Key report folder. Source reports are hashed before processing and checked again before the bundle is finalized; the originals are never edited.

## Profiles

- **Standard** redacts Windows user paths, account fields, host-name fields, serial fields, email addresses, MAC addresses, IPv4 addresses, and common IPv6 addresses.
- **Strict** applies Standard rules plus network identity fields, web URLs, UNC paths, and GUID-style identifiers.
- Optional custom regular expressions can be supplied from the command line with `-CustomPattern`.

## Output

Each run creates:

- `Lazarus-SafeReport-<timestamp>.zip`
- a companion `.zip.sha256` checksum
- `manifest.json` inside the ZIP with per-file hashes and redaction counts
- `SHA256SUMS.txt` inside the ZIP for independent verification

The manifest records counts and hashes only. It does not record the original sensitive values.

## Manual use

```powershell
.\New-SafeReportBundle.ps1 `
  -SourceDirectory 'Q:\Reports\System-Info-EXAMPLE-20260818-120000' `
  -OutputDirectory 'Q:\Reports\Safe-Bundles' `
  -Profile Strict

.\Test-SafeReportBundle.ps1 `
  -BundlePath 'Q:\Reports\Safe-Bundles\Lazarus-SafeReport-20260818-120500000.zip'
```

Sanitization reduces accidental disclosure risk but is not a substitute for technician review. Always inspect the sanitized files before sharing them.
