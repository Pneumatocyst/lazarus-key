# Build Lazarus Key on Windows

## Requirements

- One 8 GB or larger USB flash drive.
- A Windows computer with administrator rights.
- The latest Ventoy Windows package.
- The Lazarus Key project files.
- Internet access for obtaining third-party images.

## 1. Identify and back up the USB

Copy everything important off the flash drive. Open Disk Management and record the disk number, capacity, and current drive letter. Disconnect unnecessary removable drives to reduce mistakes.

## 2. Install Ventoy

1. Download Ventoy from its official site and verify its published checksum.
2. Extract the package and run `Ventoy2Disk.exe` as administrator.
3. Select the 8 GB flash drive by capacity and device name.
4. Under **Option > Partition Style**, select **MBR** for broad legacy BIOS and UEFI compatibility.
5. Under **Option > Partition Configuration**, reserve **1024 MB** at the end of the disk.
6. Leave Secure Boot support enabled unless testing identifies a compatibility issue.
7. Select **Install**, read the destructive warnings, and re-check the target before confirming.

Ventoy installation is the only destructive part of this build.

## 3. Create LAZARUS_DATA

Use Disk Management to create a new simple volume in the 1,024 MB unallocated space:

- Label: `LAZARUS_DATA`
- Filesystem: exFAT
- Allocation unit: Default

Create these folders:

```text
LAZARUS_DATA:\Drivers
LAZARUS_DATA:\Reports
LAZARUS_DATA:\Recovered-Files
LAZARUS_DATA:\Technician-Notes
```

## 4. Deploy Lazarus Key project content

Open an elevated Windows PowerShell prompt in the project directory:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Deploy-LazarusKey.ps1 -TargetDrive E:
```

Replace `E:` with the large Ventoy data partition's actual drive letter. The deployment script only copies project files; it never formats or partitions the drive.

## 5. Add the ISO images

Download each image from the official page listed in `manifests/images.json`.

Place them at exactly:

```text
LAZARUSKEY:\ISO\Windows\HBCD_PE_x64.iso
LAZARUSKEY:\ISO\Linux\systemrescue-13.02-amd64.iso
```

Do not rename the files unless you also update both `ventoy.json` and the manifest.

## 6. Validate

```powershell
.\scripts\Validate-LazarusKey.ps1 -Root E:
```

The validator checks project files, parses the Ventoy configuration, verifies the theme target, locates required images, and validates their SHA-256 hashes.

## 7. Launch inside Windows

Open:

```text
E:\Launcher\Launch-LazarusKey.cmd
```

Generate a sample support report and confirm that it is written to `LAZARUS_DATA:\Reports` when that partition is mounted.

## 8. Boot-test

Follow `TEST-PLAN.md`. At minimum, confirm the themed menu, Hiren's BootCD PE, SystemRescue, keyboard input, storage visibility, network hardware, and a clean return to the local operating system.
