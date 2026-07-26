#!/usr/bin/env bash
# Generate .config with KSU+susfs flags, run olddefconfig.
# KERNEL_DEFCONFIG default = floral_defconfig (coral's defconfig).
# O=out isolates auto.conf into out/include/config/.
#
# We do NOT append the fragment to ${KERNEL_DEFCONFIG} — this leaves
# the pristine defconfig file untouched. Apply KSU flags via
# `scripts/config --enable` POST-olddefconfig instead. The fragment
# file lives at kernel-defconfig-fragments/ksu-susfs.config.
#
# Direct kernel source layout: $KERNEL_DIR/ == kernel root (no
# private/msm-google/ subdir). With direct git clone of kernel/msm,
# everything is at top level.
set -euo pipefail

KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-floral_defconfig}"
OUT_DIR="${OUT_DIR:-out}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
FRAGMENT="$REPO_ROOT/kernel-defconfig-fragments/ksu-susfs.config"

export ARCH=arm64
export PATH="/usr/bin:${PATH}"

cd "$KERNEL_SRC"

echo "[3] make O=out ${KERNEL_DEFCONFIG}"
COMMON_OUT_DIR="$REPO_ROOT/$KERNEL_DIR/$OUT_DIR"
rm -rf "$COMMON_OUT_DIR"
mkdir -p "$COMMON_OUT_DIR"
make O="$COMMON_OUT_DIR" ARCH=arm64 "$KERNEL_DEFCONFIG" 2>&1 | tail -5

echo "[3] make O=out olddefconfig"
make O="$COMMON_OUT_DIR" ARCH=arm64 olddefconfig 2>&1 | tail -5

echo "[3] Apply KSU+susfs flags via scripts/config --enable"
ENABLE_FLAGS=(
  CONFIG_KSU
  CONFIG_KSU_KPROBES_HOOK
  CONFIG_KSU_SUSFS
  CONFIG_KSU_SUSFS_SUS_PATH
  CONFIG_KSU_SUSFS_SUS_MOUNT
  CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
  CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
  CONFIG_KSU_SUSFS_SUS_KSTAT
  CONFIG_KSU_SUSFS_TRY_UMOUNT
  CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT
  CONFIG_KSU_SUSFS_SPOOF_UNAME
  CONFIG_KSU_SUSFS_ENABLE_LOG
  CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
  CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
  CONFIG_KSU_SUSFS_OPEN_REDIRECT
  CONFIG_KALLSYMS
  CONFIG_KALLSYMS_ALL
  CONFIG_KPROBES
  CONFIG_HAVE_KPROBES
)
DISABLE_FLAGS=(
  CONFIG_KSU_MANUAL_HOOK
  CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT
  CONFIG_KSU_SUSFS_SUS_OVERLAYFS
)
for f in "${ENABLE_FLAGS[@]}"; do
  ./scripts/config --file "$COMMON_OUT_DIR/.config" --enable "$f" || true
done
for f in "${DISABLE_FLAGS[@]}"; do
  ./scripts/config --file "$COMMON_OUT_DIR/.config" --disable "$f" || true
done

echo "[3] make O=out olddefconfig (after enabling KSU)"
make O="$COMMON_OUT_DIR" ARCH=arm64 olddefconfig 2>&1 | tail -5

echo "[3] KSU/kprobes flags in $COMMON_OUT_DIR/.config:"
grep -E "^CONFIG_KSU|^CONFIG_KPROBES" "$COMMON_OUT_DIR/.config" || echo "  (no KSU/kprobes flags!)"