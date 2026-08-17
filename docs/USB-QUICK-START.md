# Lazarus Key quick start

## Boot recovery environments

1. Insert the Lazarus Key while the computer is powered off.
2. Start the computer and open its one-time boot menu, commonly with F9, F10, F11, F12, or Esc.
3. Select the USB device.
4. Choose a recovery environment from the Lazarus Key menu.

Use Hiren's BootCD PE for Windows-focused repair and SystemRescue for Linux filesystems, partitioning, imaging, networking, and lower-level recovery.

## Use from running Windows

Open the main Lazarus Key volume, then run:

```text
Launcher\Launch-LazarusKey.cmd
```

The launcher can create read-only system, network, storage, and recent-event reports.

## Storage

Use `LAZARUS_DATA` for reports, drivers, technician notes, and explicitly recovered files. Do not store passwords, private keys, BitLocker recovery keys, or unencrypted sensitive records on the Lazarus Key.

## Before making changes

- Confirm you are authorized to service the computer.
- Identify the internal disk by model, serial number, and capacity.
- Back up important data when possible.
- Read every partitioning, imaging, erase, and restore confirmation carefully.
- Never assume `/dev/sda`, Disk 0, or the first listed disk is the intended target.
