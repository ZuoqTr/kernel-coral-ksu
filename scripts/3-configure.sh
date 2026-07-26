#!/usr/bin/env bash
# Append KSU+susfs defconfig fragment, run defconfig + olddefconfig.
# KERNEL_DEFCONFIG default = floral_defconfig (coral's defconfig).
# O=out isolates auto.conf into out/include/config/ — required for
# 4.14 msm to avoid the silentoldconfig pattern-rule loop in
# Makefile:619-620 (kbuild re-fires the rule when auto.conf.cmd mtime
# drifts ahead of .config).
#
# build.sh from manifest pin handles toolchain (Clang + GCC 4.9).
# We only need make for the config phases; no C compile happens here.
set -euo pipefail

KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-floral_defconfig}"
OUT_DIR="${OUT_DIR:-out}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"
KERNEL_SRC="$KERNEL_DIR/private/msm-google"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export ARCH=arm64
export HOSTCC=clang

cd "$KERNEL_SRC"

echo "[3] Appending KSU+susfs fragment to ${KERNEL_DEFCONFIG}"
cat "$REPO_ROOT/kernel-defconfig-fragments/ksu-susfs.config" >> "arch/arm64/configs/${KERNEL_DEFCONFIG}"

echo "[3] make O=out ${KERNEL_DEFCONFIG}"
rm -rf "$KERNEL_DIR/$OUT_DIR"
mkdir -p "$KERNEL_DIR/$OUT_DIR"
make O="$KERNEL_DIR/$OUT_DIR" ARCH=arm64 "$KERNEL_DEFCONFIG" 2>&1 | tail -5

echo "[3] make O=out olddefconfig"
make O="$KERNEL_DIR/$OUT_DIR" ARCH=arm64 olddefconfig 2>&1 | tail -5

echo "[3] KSU flags in $KERNEL_DIR/$OUT_DIR/.config:"
grep -E "^CONFIG_KSU" "$KERNEL_DIR/$OUT_DIR/.config" || echo "  (no CONFIG_KSU flags!)"