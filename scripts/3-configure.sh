#!/usr/bin/env bash
# Append KSU+susfs defconfig fragment, run defconfig with O=out.
# O=out is REQUIRED: in-tree builds on 4.14 msm re-trigger the
# `include/config/auto.conf` pattern rule in a silentoldconfig loop
# because the build's own dependency-touching rewrites auto.conf.cmd
# with mtime > the producing .config, making the pattern rule at
# Makefile:619-620 re-fire forever. O=out isolates auto.conf into
# out/include/config/ where the source tree's pattern rule can't
# chase it.
set -euo pipefail

KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-floral_defconfig}"
OUT_DIR="${OUT_DIR:-out}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export PATH="/usr/bin:${PATH}"

cd kernel

echo "[3] Appending KSU+susfs fragment to ${KERNEL_DEFCONFIG}"
cat ../kernel-defconfig-fragments/ksu-susfs.config >> "arch/arm64/configs/${KERNEL_DEFCONFIG}"

echo "[3] make O=out ${KERNEL_DEFCONFIG}"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
make O="$OUT_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$KERNEL_DEFCONFIG" 2>&1 | tail -5

# Done. Do NOT run olddefconfig/silentoldconfig separately; the O=out
# build's implicit silentoldconfig pass during compile handles any drift
# in a single pass without the recursive-loop pattern.
# See https://github.com/ZuoqTr/kernel-coral-ksu (CLAUDE.md / commit
# history) for the full analysis.

echo "[3] KSU flags in out/.config:"
grep -E "^CONFIG_KSU" "$OUT_DIR/.config" || echo "  (no CONFIG_KSU flags!)"
