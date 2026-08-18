# Case Workspace

The Case Workspace organizes an authorized support session beneath a unique, non-identifying case folder. It tracks local metadata, technician notes, report runs, status, activity, a browsable HTML summary, and privacy-safe handoff bundles.

## Storage layout

```text
LAZARUSDATA:\Cases\LK-YYYYMMDD-HHMMSS-ABCD\
├── case.json
├── technician-notes.md
├── case-summary.html
├── Reports\
├── Attachments\
└── Safe-Bundles\
```

Only the case ID appears in the folder name. Titles, customer names, ticket numbers, and device names stay inside the local metadata file.

When a case is active, the built-in launcher reports, System Info Collector, and Network Troubleshooter route new output to its `Reports` directory. Clearing the active case restores the normal `Reports` workflow.

The **Package Strict Handoff** action uses Lazarus Key's existing Safe Report Packager. It removes the case title, ticket, customer, device, technician identity, and normal report identifiers from copied content, then creates a hashed and independently verifiable ZIP. Originals remain unchanged. Pattern-based redaction still requires human review.

Do not store passwords, private keys, BitLocker recovery keys, authentication tokens, or unrelated personal records in a case.
