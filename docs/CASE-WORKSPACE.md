# Case Workspace

Case Workspace is the v0.5 technician handoff workflow. It groups reports and notes by authorized support case without changing how the individual diagnostic tools operate.

## Create and activate a case

Open **Case Workspace** from the Windows launcher and select **New Case**. Enter only the minimum information needed for the support task:

- Case title
- Ticket number
- Customer or device owner
- Device name

The new case becomes active automatically. While a case is active, the built-in support, network, and storage reports plus the System Info Collector and Network Troubleshooter route their output into it. Select **Clear Active** to return new reports to the normal `Reports` directory.

## Case layout

Cases are stored on `LAZARUSDATA` when that partition is mounted. The main Lazarus Key partition is the fallback.

```text
Cases\LK-YYYYMMDD-HHMMSS-ABCD\
├── case.json
├── technician-notes.md
├── case-summary.html
├── Reports\
├── Attachments\
└── Safe-Bundles\
```

The folder name contains only a generated case ID. Customer, ticket, title, device, and technician values remain inside local case files.

## Technician workflow

1. Create and activate the case.
2. Run read-only diagnostics first.
3. Add concise notes describing symptoms, authorization, actions, and results.
4. Change status through Open, In Progress, Resolved, and Closed.
5. Open the HTML summary to review the case index.
6. Select **Package Strict Handoff** when a sanitized copy is required.
7. Verify and manually inspect the generated ZIP before sharing it.

## Handoff privacy

Strict handoff packaging creates temporary copies and redacts the case title, ticket, customer, device, technician identity, and all identifiers already covered by the Safe Report Packager. The output contains case details, copied technician notes, supported report files, `manifest.json`, and `SHA256SUMS.txt`. A companion `.sha256` file protects the ZIP. Source reports are hashed before and after the operation and are never edited.

Standard handoffs preserve case metadata while applying standard report redaction. The graphical manager intentionally defaults to Strict. Pattern-based redaction cannot identify every possible secret or personal value, so always review a handoff before transmitting it.

## Safety

- Do not store passwords, access tokens, private keys, BitLocker recovery keys, or unrelated personal records.
- Attach files deliberately; attachments are not automatically included in handoff bundles.
- Closing a case changes its status but does not delete it.
- Case deletion is intentionally absent from the v0.5 interface to prevent accidental evidence loss.
