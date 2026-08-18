# Architecture

## Design goals

Lazarus Key is optimized for a nominal 8 GB flash drive and for technicians who need a small, understandable toolkit rather than a giant collection of overlapping images.

The design prioritizes:

1. Broad Windows and Linux repair coverage with two core images.
2. Read-only diagnostics before mutation.
3. Clear separation between boot environments, technician utilities, and collected data.
4. Reproducibility through manifests, hashes, validation, and source-controlled configuration.
5. Safe public distribution without repackaging third-party binaries.

## Component flow

```mermaid
flowchart TD
    A[Computer firmware] --> B[Ventoy boot menu]
    B --> C[Hiren's BootCD PE]
    B --> D[SystemRescue]
    B --> E[Optional diagnostic images]
    F[Running Windows] --> G[Lazarus Key launcher]
    G --> H[Built-in read-only reports]
    G --> I[System Info Collector]
    G --> J[Network Troubleshooter]
    G --> K[Safe Report Packager]
    G --> M[Portable Tools Manager]
    G --> R[Case Workspace]
    M --> O[Official upstream archives]
    O --> P[Size, SHA-256, path, and publisher checks]
    P --> Q[Staged PortableTools installation]
    H --> L[LAZARUSDATA or local Reports]
    I --> L
    J --> L
    H --> R
    I --> R
    J --> R
    R --> S[Case reports, notes, activity, and HTML index]
    S --> K
    L --> K
    K --> N[Sanitized ZIP, manifest, and hashes]
```

## Trust boundaries

| Boundary | Project behavior |
| --- | --- |
| Firmware to Ventoy | Ventoy handles legacy BIOS and UEFI booting. Secure Boot behavior depends on firmware and Ventoy enrollment. |
| Ventoy to ISO | ISO files are independently downloaded and verified against pinned SHA-256 hashes. |
| Launcher to Windows | The launcher invokes Windows management consoles and read-only PowerShell collection. |
| Reports to storage | Reports may contain sensitive device and network details and are excluded from source control. |
| Reports to active case | An active pointer contains only a generated case ID. Report runs route to that case until the technician clears or changes it. |
| Case to handoff | Strict mode replaces case-specific values and passes temporary copies through the existing redaction and integrity pipeline. Attachments are excluded. |
| Reports to sanitized bundle | Source files remain unchanged. Redacted copies, integrity hashes, and counts are written to a new bundle that still requires human review. |
| Catalog to upstream archive | Downloads require HTTPS, an allowed host, explicit license acceptance, exact byte size, and a pinned SHA-256 hash. |
| Archive to installed tool | ZIP paths, launcher presence, disk space, and cataloged publisher signatures are checked before staged installation. |
| Third-party tools | Binaries are never committed or released by Lazarus Key. Their behavior and license obligations remain the responsibility of their publishers and the technician. |

## Update strategy

- Update one ISO at a time.
- Record the upstream version, size, official URL, and SHA-256 in the manifest.
- Update any Ventoy menu aliases that contain versioned filenames.
- Run project validation.
- Re-run the physical test matrix before publishing a release.
- For portable tools, update one catalog entry at a time and retain fail-closed pinned hashes rather than floating latest-version URLs.

## Why two primary ISOs

Hiren's BootCD PE provides a familiar Windows graphical environment. SystemRescue supplies current Linux filesystem, storage, networking, imaging, and memory tools. Together they cover the main rescue cases while leaving usable space on an 8 GB drive.
