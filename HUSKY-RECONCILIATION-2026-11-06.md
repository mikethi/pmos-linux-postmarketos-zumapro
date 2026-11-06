# Husky Omarchy vs PMOS reconciliation snapshot

**Date:** 2026-11-06  
**PMOS repository:** `mikethi/pmos-linux-postmarketos-zumapro`, branch `edge`, at `ac0a7897d5baa7d9459ce2ebb047c442fc5a0f1e`  
**Omarchy reference:** `derekross/omarchy-mobile`, `main`, at `cd306956ee0ac9746d4db6ffcb00229f23d6f3ed`

## Execution note

The GitHub API environment used for this update can read and write repository files but cannot launch a shell or check out repositories. Therefore `tools/husky-reconcile.sh` was **not executed** here. This snapshot records a manual, read-only reconciliation of the script's checks against the repository files retrieved from GitHub. Run the script locally to obtain its actual output:

```sh
bash tools/husky-reconcile.sh /path/to/omarchy-mobile [/path/to/omarchy-kernel]
```

No kernel, DTS/DTB, boot image, configuration, or flash operation was changed by this audit.

## Findings

| Area | Check | Status | Evidence / interpretation |
|---|---|---|---|
| Boot descriptor | `SOC=zuma` | MISSING | The PMOS repository root has no `device.conf`; the value cannot be verified there. Omarchy declares `SOC=zuma`. |
| Boot descriptor | Husky DTB path | MISSING | No PMOS `device.conf` was found to declare `DTB=exynos/google/zuma-husky.dtb`. |
| Boot descriptor | `SOC_COMPATIBLE` | MISSING | PMOS descriptor value is not present in the checked repository files. Omarchy specifies the B0/B1 FOPLP selector. |
| Boot descriptor | `AVB_FOOTERS` | MISSING | PMOS descriptor value is not present in the checked repository files. Omarchy specifies `boot:0x4000000 init_boot:0x800000`. |
| Boot descriptor | `SIMPLEFB_TRIG_CON` | MISSING | PMOS descriptor value is not present in the checked repository files. Omarchy specifies `0x19470030 0x3061`. |
| Kernel config | `CONFIG_PHY_SNPS_EUSB2=y` | MATCH | The PMOS config contains the symbol built in. This satisfies the Stage 0 early-USB configuration finding; it does not prove USB operation. |
| Device tree | `google,zuma` root compatible token | MATCH | The PMOS `husky.dts` contains this compatible token. Text presence alone does not establish a correct compiled or live tree. |
| Device tree | `/soc_compatible` token | MATCH | The PMOS `husky.dts` contains a `soc_compatible` node. Match its selector content and ABL behavior separately. |
| Device tree | `reserved-memory` token | MATCH | The PMOS `husky.dts` contains reserved-memory source. Layout equivalence or ABL acceptance is not inferred. |
| Device tree | PMU reboot-mode source | UNVERIFIED | This check needs a direct source scan of the full DTS; no hardware reboot test is inferred. |
| Kernel source | Driver implementations | UNVERIFIED | The PMOS repository is a kernel package/config/DTS repository, not a complete kernel source checkout. The optional Omarchy kernel source path was not supplied to this static review. |
| Runtime evidence | Physical-device boot | UNVERIFIED | Omarchy's documented boot does not prove this PMOS build boots. |
| Runtime evidence | USB enumeration and SSH | UNVERIFIED | Requires PMOS device logs or an explicitly recorded PMOS test. |
| Runtime evidence | Panel console | UNVERIFIED | Requires PMOS device validation. |
| Runtime evidence | DWC3 rebind cycles | UNVERIFIED | Requires PMOS device validation against the relevant PHY reset fix. |
| Runtime evidence | UFS read/write | UNVERIFIED | Omarchy's reported read-only UFS result does not prove PMOS UFS behavior; read-only and writable storage are distinct milestones. |
| Runtime evidence | PMOS initramfs/root mount | UNVERIFIED | This static repository comparison does not establish root filesystem integration. |

## Interpretation

The strongest direct source-level match is the built-in eUSB2 PHY setting. PMOS also has recognizable Zuma and reserved-memory DTS text. The descriptor/AVB/initramfs parameters are **not established by the current PMOS repository files**, because there is no PMOS `device.conf` in the checked tree. This is a missing source of evidence, not proof that the values are wrong or absent from an external build process.

The Omarchy Stage 0 runbook documents physical Husky kernel/initramfs bring-up, USB/SSH, panel console, watchdog handling, and subsequent DWC3/UFS work. Those results remain reference evidence only; all PMOS runtime checks stay `UNVERIFIED` until tested on the PMOS build.

## Reference files

- PMOS: `APKBUILD`, `config-postmarketos-zumapro.aarch64`, `husky.dts`
- Omarchy: `device/husky/device.conf`, `device/husky/kernel.config`, `device/husky/BRINGUP-M1.md`
- Read-only checker: `tools/husky-reconcile.sh`
