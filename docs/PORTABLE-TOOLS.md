# Portable tools catalog and acquisition policy

Lazarus Key does not redistribute third-party utilities. The v0.4 manager reads `portable-tools.json`, shows the upstream license and source, and downloads a selected archive directly to the technician's computer. Installation stops unless the archive's exact byte size and SHA-256 hash match the pinned catalog values.

## Initial catalog

| Tool | Version | Default | Download | Installed estimate | License |
| --- | --- | --- | ---: | ---: | --- |
| Everything Search | 1.4.1.1032 x64 | Yes | 1.8 MiB | 3.2 MiB | MIT-style upstream license |
| Notepad++ Portable | 8.9.6.1 x64 | Yes | 7.7 MiB | 25.1 MiB | GPL-3.0-or-later |
| TestDisk and PhotoRec | 7.2 x64 | Yes | 26.1 MiB | 76.2 MiB | GPL-2.0-or-later |
| CrystalDiskInfo | 9.9.1 x64 | Yes | 8.1 MiB | 19.1 MiB | MIT with bundled-component notices |
| Microsoft Sysinternals Suite | 2026.07 x64 | No | 191.8 MiB | 272.2 MiB | Microsoft Sysinternals terms |

The four defaults total approximately 44 MiB of downloads and 124 MiB after extraction. The full catalog totals approximately 236 MiB of downloads and 396 MiB after extraction.

## Why Sysinternals is download-only

Microsoft permits use on devices a technician supports but explicitly states that it does not offer third-party distribution licenses. Lazarus Key therefore stores only Microsoft’s official download URL, current metadata, and a pinned hash. The manager downloads the archive directly from Microsoft after license confirmation and verifies Microsoft Authenticode publisher signatures before installation.

## Installation controls

1. Validate catalog structure, HTTPS origin, allowed host, license metadata, sizes, hashes, and safe relative paths.
2. Require the technician to accept the displayed upstream licenses.
3. Check temporary and destination free space.
4. Download to a temporary file or accept an explicitly supplied offline archive.
5. Require exact archive size and SHA-256 values.
6. Reject absolute paths, drive-qualified paths, empty segments, and `..` traversal in ZIP entries.
7. Extract to a staging directory and verify every expected launcher.
8. Apply cataloged publisher-signature requirements to every exposed launcher.
9. Write an installation receipt and move the staged folder into place.
10. Never start an installed tool until the technician deliberately selects **Launch Primary**.

An update replaces the entire catalog-managed tool directory only after a separate confirmation. Configuration stored inside that directory may be removed during an update.

## Updating the catalog

Do not use an unpinned “latest” download in a release. For each update:

1. Confirm the release on the publisher’s official page.
2. Review the upstream license and redistribution language.
3. Download the exact portable archive from the recorded source.
4. Record the exact archive length and SHA-256 hash.
5. Inspect its directory structure and launcher paths.
6. Update one catalog entry at a time.
7. Run `Test-PortableToolsCatalog.ps1` and `Test-PortableTools.ps1`.
8. Perform a real Windows download, install, verify, launch, and managed-update test.

If an upstream publisher replaces a file at the same URL, the pinned size or hash will fail closed. Review and update the catalog; never bypass the mismatch.
