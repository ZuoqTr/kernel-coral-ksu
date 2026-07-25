#!/usr/bin/env bash
# Append KSU+susfs fragment to defconfig, sync mtimes, exit.
# CRITICAL: do NOT run make olddefconfig/silentoldconfig here. The 4.14
# kbuild writes auto.conf.cmd referencing the producing conf command; any
# subsequent configuration step (including -j implicit silentoldconfig
# inside 4-build.sh) sees a stale dependency and the pattern rule
# scripts/kconfig/conf --silentoldconfig Kconfig at Makefile:619-620
# re-fires indefinitely.
#
# Strategy: produce .config exactly once with floral_defconfig (which
# already includes our appended KSU+susfs options). Freeze auto.conf
# mtimes so the build's dependency check is satisfied. Do not invoke
# make for any other purpose before 4-build.sh.
set -euo pipefail

KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-floral_defconfig}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export PATH="/usr/bin:${PATH}"

cd kernel

echo "[3] Appending KSU+susfs fragment to ${KERNEL_DEFCONFIG}"
cat ../kernel-defconfig-fragments/ksu-susfs.config >> "arch/arm64/configs/${KERNEL_DEFCONFIG}"

echo "[3] make ${KERNEL_DEFCONFIG} (single config pass, no olddefconfig)"
# -B forces re-evaluation; -j1 keeps make from re-entering silentoldconfig
# inside the build tree; we then immediately freeze mtimes so the build
# does not retrigger the same pattern rule.
make -j1 -B ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$KERNEL_DEFCONFIG" 2>&1 | tail -5

echo "[3] Freezing kconfig mtimes (force auto.conf/auto.conf.cmd older than .config)"
# .config is the source of truth. Anything autogen'd must be older or
# the recursive silentoldconfig pattern at Makefile:619 will re-fire.
touch -d '2000-01-01' include/config/auto.conf include/config/auto.conf.cmd \
  include/config/tristate.conf 2>/dev/null || true
touch .config

echo "[3] KSU flags in .config:"
grep -E "^CONFIG_KSU" .config || echo "  (no CONFIG_KSU flags!)"
# STOP. Do not run any additional make config invocation.
