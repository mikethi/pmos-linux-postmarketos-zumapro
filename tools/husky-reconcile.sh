#!/usr/bin/env bash
# Read-only Omarchy Husky Stage 0 vs PMOS source comparison.
# Usage: bash tools/husky-reconcile.sh /path/to/omarchy-mobile [kernel-source]
# Prints findings only; does not build, modify, flash, or probe hardware.
set -u

PMOS_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OMARCHY_ROOT=${1:?Usage: bash tools/husky-reconcile.sh OMARCHY_ROOT [OMARCHY_KERNEL_ROOT]}
KERNEL_ROOT=${2:-}
[[ -d "$OMARCHY_ROOT" ]] || { echo "Missing Omarchy directory: $OMARCHY_ROOT" >&2; exit 2; }

PMOS_CONFIG="$PMOS_ROOT/config-postmarketos-zumapro.aarch64"
PMOS_DTS="$PMOS_ROOT/husky.dts"
PMOS_DESC="$PMOS_ROOT/device.conf"
REF_DESC="$OMARCHY_ROOT/device/husky/device.conf"
REF_CONFIG="$OMARCHY_ROOT/device/husky/kernel.config"

value() {
  # Read a literal KEY=value without sourcing the file.
  local file=$1 key=$2
  [[ -r "$file" ]] || return 1
  sed -nE "s/^[[:space:]]*(CONFIG_)?${key}=(.*)$/\\2/p" "$file" | head -n1 | tr -d '"'
}
report() {
  local area=$1 item=$2 status=$3 pmos=$4 reference=$5 note=$6
  printf '%-22s | %-31s | %-14s | PMOS: %-40s | Omarchy: %s\n' "$area" "$item" "$status" "$pmos" "$reference"
  printf '  %s\n' "$note"
}
compare_value() {
  local key=$1 expected=$2 got
  got=$(value "$PMOS_DESC" "$key" 2>/dev/null || true)
  if [[ -z "$got" ]]; then
    report 'Boot descriptor' "$key" MISSING 'absent' "$expected" 'No matching literal assignment in the PMOS tree.'
  elif [[ "$got" == "$expected" ]]; then
    report 'Boot descriptor' "$key" MATCH "$got" "$expected" 'Values match; this is static source evidence only.'
  else
    report 'Boot descriptor' "$key" CONFLICT "$got" "$expected" 'PMOS value differs from the Stage 0 reference.'
  fi
}
compare_config() {
  local key=$1 expected=$2 got
  got=$(value "$PMOS_CONFIG" "$key" 2>/dev/null || true)
  if [[ "$got" == "$expected" ]]; then
    report 'Kernel config' "CONFIG_$key" MATCH "$got" "$expected" 'Required setting matches.'
  elif [[ -z "$got" ]]; then
    report 'Kernel config' "CONFIG_$key" MISSING 'absent' "$expected" 'Required built-in setting not explicitly enabled.'
  else
    report 'Kernel config' "CONFIG_$key" CONFLICT "$got" "$expected" 'Value differs from the Stage 0 requirement.'
  fi
}
contains() { [[ -r "$1" ]] && grep -Fqi -- "$2" "$1"; }

printf '%-22s | %-31s | %-14s | %s\n' AREA CHECK STATUS DETAILS
printf '%s\n' '-----------------------+---------------------------------+----------------+----------------------------------------------'
compare_value SOC zuma
compare_value DTB exynos/google/zuma-husky.dtb
compare_value SOC_COMPATIBLE 'b0-foplp:0x9865:1:0:0 b1-foplp:0x9865:1:1:0'
compare_value AVB_FOOTERS 'boot:0x4000000 init_boot:0x800000'
compare_value SIMPLEFB_TRIG_CON '0x19470030 0x3061'
compare_config PHY_SNPS_EUSB2 y

for pair in 'google,zuma|Root compatible' 'soc_compatible|/soc_compatible node' 'reserved-memory|Reserved-memory source' 'reboot-mode|PMU reboot-mode source'; do
  token=${pair%%|*}; label=${pair#*|}
  if contains "$PMOS_DTS" "$token"; then
    report 'Device tree' "$label" MATCH "$PMOS_DTS contains token" 'Omarchy Husky source' 'Presence only; compare compiled and live trees independently.'
  else
    report 'Device tree' "$label" UNVERIFIED "$PMOS_DTS not matched" 'Omarchy Husky source' 'Text scan cannot prove absence or runtime behavior.'
  fi
done

for name in 'BRINGUP-M1.md' 'NOTES.md' 'UFS-PLAN.md'; do
  if [[ -r "$OMARCHY_ROOT/device/husky/$name" ]]; then
    report 'Reference evidence' "$name" MATCH 'PMOS has no paired evidence file' "device/husky/$name" 'Read the cited runbook; its hardware results do not prove PMOS behavior.'
  else
    report 'Reference evidence' "$name" UNVERIFIED 'not checked in' "device/husky/$name" 'Expected reference document was not found at this path.'
  fi
done

if [[ -n "$KERNEL_ROOT" && -d "$KERNEL_ROOT" ]]; then
  for token in 'PHY_SNPS_EUSB2' 'dwc3' 'watchdog' 'reboot-mode'; do
    p=$(grep -RIlF --exclude-dir=.git --exclude='*.dtb' -- "$token" "$PMOS_ROOT" 2>/dev/null | head -n1 || true)
    r=$(grep -RIlF --exclude-dir=.git --exclude='*.dtb' -- "$token" "$KERNEL_ROOT" 2>/dev/null | head -n1 || true)
    if [[ -n "$p" && -n "$r" ]]; then s=MATCH; note='Keyword in both trees only; inspect implementation and revision.'
    elif [[ -n "$r" ]]; then s=MISSING; note='Reference keyword not found in PMOS checkout.'
    elif [[ -n "$p" ]]; then s=CONFLICT; note='Keyword found only in PMOS; reference naming/path may differ.'
    else s=UNVERIFIED; note='No text hits; source naming may differ.'; fi
    report 'Kernel source scan' "$token" "$s" "${p:-no hit}" "${r:-no hit}" "$note"
  done
else
  report 'Kernel source scan' 'Driver implementations' UNVERIFIED 'No kernel source scan' 'Pass optional kernel-source path; configs alone do not prove driver implementation.'
fi

for item in 'Physical-device boot' 'USB enumeration and SSH' 'Panel console' 'DWC3 rebind cycles' 'UFS read/write' 'PMOS initramfs/root mount'; do
  report 'Runtime evidence' "$item" UNVERIFIED 'Not established by source scan' 'Omarchy reports are not PMOS test results' 'Requires PMOS device logs or an explicitly recorded test.'
done
printf '\nRead-only text comparison; MATCH is not hardware validation or proof of semantic equivalence.\n'
