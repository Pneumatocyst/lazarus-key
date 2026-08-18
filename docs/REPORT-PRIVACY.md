# Report privacy and safe sharing

Lazarus Key reports can contain usernames, computer names, serial numbers, network addresses, DNS information, URLs, and other environment details. Treat every raw report as sensitive operational data.

## Safe Report Packager

The packager reads an existing report folder and writes sanitized copies into a new ZIP. It does not edit, rename, move, or delete the source reports. The tool hashes each source file before processing and checks the hash again before finalizing the bundle.

Supported source formats are TXT, LOG, JSON, and CSV. Other file types are not included.

| Profile | Intended use | Additional behavior |
| --- | --- | --- |
| Standard | Internal support handoff | Redacts user paths, account fields, computer-name fields, serial fields, email addresses, MAC addresses, and common IPv4/IPv6 addresses. |
| Strict | External sharing; recommended default | Applies Standard rules plus DNS/domain/SSID fields, URLs, UNC paths, and GUID-style identifiers. |

Custom regular expressions can be supplied during manual command-line use. A malformed custom expression is rejected before output is created.

## Bundle integrity

Each bundle contains:

- sanitized report copies;
- `manifest.json`, including the selected profile, per-file SHA-256 values, and redaction counts;
- `SHA256SUMS.txt`, covering every sanitized file and the manifest;
- a companion `.zip.sha256` file beside the ZIP.

Run the verifier before relying on a transferred bundle:

```powershell
.\Test-SafeReportBundle.ps1 -BundlePath .\Lazarus-SafeReport-<timestamp>.zip
```

The verifier rejects unsafe archive or manifest paths, undeclared payload files, incomplete checksum sets, and hash mismatches.

Hashes demonstrate integrity, not authorship. v0.3.0 does not store a private signing key on the USB and does not claim that hash files are digital signatures.

## Limitations

Pattern-based redaction can produce false negatives and false positives. Unexpected identifiers may remain, and values that resemble IP addresses or identifiers may be removed even when they are not sensitive. The tool cannot determine the authorization level of a recipient.

Before sharing:

1. Extract the sanitized ZIP.
2. Review every included report.
3. Confirm the bundle contains no credentials, recovery keys, patient information, private keys, tokens, or unrelated files.
4. Verify the bundle hash through a separate trusted channel when integrity matters.
5. Share only through an approved organizational method.

Never treat sanitization as permission to disclose data that policy, law, contract, or the system owner prohibits sharing.
