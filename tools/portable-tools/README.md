# Portable Tools Manager

The manager downloads optional Windows technician tools directly from their official upstream sources. Third-party binaries are never stored in this repository or bundled in a Lazarus Key release.

## Safety controls

- Requires explicit upstream-license acceptance before download or installation.
- Accepts only cataloged HTTPS sources and allowed hostnames.
- Requires the exact pinned archive size and SHA-256 hash.
- Rejects unsafe ZIP paths before extraction.
- Checks destination and temporary-disk free space.
- Extracts to a staging directory and replaces an existing managed folder only with `-Force`.
- Verifies expected launcher paths before installation.
- Verifies Microsoft Authenticode publisher signatures for the Sysinternals Suite.
- Writes `.lazarus-tool.json` receipts and never executes a download automatically.

## Graphical use

Open the Lazarus Key launcher and select **Tool Manager**. Select tools, inspect their source and license information, confirm the download, and use **Verify Installed** before launching them.

## Command-line use

```powershell
.\Install-PortableTool.ps1 `
  -ToolId everything,notepad-plus-plus `
  -CatalogPath 'D:\Documentation\portable-tools.json' `
  -DestinationRoot 'D:\PortableTools' `
  -AcceptLicense

.\Test-InstalledPortableTools.ps1 `
  -CatalogPath 'D:\Documentation\portable-tools.json' `
  -DestinationRoot 'D:\PortableTools'
```

Use `-Force` only to replace the entire managed folder for an existing tool. Review destructive or recovery actions inside third-party tools before applying changes to an authorized system.
