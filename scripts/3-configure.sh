#!/usr/bin/env bash
# Append KSU+susfs defconfig fragment, run defconfig + olddefconfig.
# In-tree build (no O=out) to avoid 4.14 silentoldconfig infinite loop.
set -euo pipefail

KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-floral_defconfig}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export PATH="/usr/bin:${PATH}"

cd kernel

echo "[3] Appending KSU+susfs defconfig fragment to ${KERNEL_DEFCONFIG}"
cat ../kernel-defconfig-fragments/ksu-susfs.config >> "arch/arm64/configs/${KERNEL_DEFCONFIG}"

echo "[3] make ${KERNEL_DEFCONFIG}"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$KERNEL_DEFCONFIG" 2>&1 | tail -5

# Use silentoldconfig (NOT olddefconfig) so include/config/auto.conf.cmd
# matches what the build will regenerate. Mixing olddefconfig here and
# silentoldconfig in the build causes an infinite re-run loop because
# auto.conf.cmd records the producing conf command.
echo "[3] make silentoldconfig"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- silentoldconfig 2>&1 | tail -5

echo "[3] KSU flags in .config:"
grep -E "^CONFIG_KSU" .config || echo "  (no CONFIG_KSU flags!)"
