#!/usr/bin/env bash
# Apply KernelSU Next manual-hooks + susfs4ksu integration.
#
# Order matters:
#  1. Setup KSU (handled by 1-setup-ksu.sh — creates drivers/kernelsu symlink)
#  2. Apply 5 manual-hooks patches (ksu_handle_* externs + calls in syscall sites)
#  3. Apply susfs4ksu kernel-4.14 patch (modifies fs/, include/, kernel/ files)
#  4. Copy susfs headers + source files into kernel tree (patch doesn't create them)
#  5. Apply 10_enable_susfs_for_ksu.patch (KSU internal: Kconfig + susfs ifdefs)
#
# v3.1.0-legacy branch uses manual hooks (no kprobes, 4.14 msm lacks
# HAVE_SYSCALL_TRACEPOINTS). Susfs4ksu was originally from
# https://gitlab.com/simonpunk/susfs4ksu, mirrored at ShirkNeko/susfs4ksu.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
HOOK_DIR="$REPO_ROOT/patches/ksu-manual-hooks"
SUSFS_DIR="$REPO_ROOT/patches/susfs-kernel-4.14"

cd "$KERNEL_SRC"

# --- step 1: setup KSU (handled by 1-setup-ksu.sh before this script) ---
echo "[2a] Verifying drivers/kernelsu symlink exists..."
test -e drivers/kernelsu || { echo "drivers/kernelsu missing — did 1-setup-ksu.sh run?"; exit 1; }
grep -q "kernelsu/" drivers/Makefile
grep -q "drivers/kernelsu/Kconfig" drivers/Kconfig

# --- step 2: manual-hooks patches ---
echo "[2b] Applying 5 manual-hooks patches..."
for p in "$HOOK_DIR"/*.patch; do
  echo "[2b]   $p"
  git apply --verbose "$p" || {
    echo "[2b] FAILED: $p"
    git apply --verbose --ignore-whitespace "$p" || exit 1
  }
done

for f in fs/exec.c fs/open.c fs/read_write.c fs/stat.c kernel/reboot.c; do
  if ! grep -q "ksu_handle_" "$f"; then
    echo "[2b] MISSING hooks in $f"; exit 1
  fi
done
echo "[2b] OK: all 5 manual hooks applied"

# --- step 3: susfs kernel-4.14 patch (modifies existing files) ---
# Use 0001-combined.patch — AOSP-coral-4.14-tailored version with the 5
# manually-fixed hunks for fs/proc/cmdline.c, fs/proc/task_mmu.c,
# fs/proc_namespace.c, include/linux/mount.h, include/linux/stat.h,
# kernel/kallsyms.c baked in. (Upstream 0001-add-susfs.patch was authored
# against a slightly different 4.14 tree and produced 5 rejects on this
# AOSP msm-floral-4.14 android10-qpr3 checkout.)
echo "[2c] Applying susfs4ksu kernel-4.14 patch (AOSP-coral-tailored combined)..."
git apply --verbose --whitespace=fix "$SUSFS_DIR/0001-combined.patch" || {
  echo "[2c] FAILED: 0001-combined.patch"
  git apply --verbose --reject --whitespace=fix "$SUSFS_DIR/0001-combined.patch" || exit 1
}

# --- step 4: copy susfs source/header files (patch doesn't create them) ---
echo "[2d] Copying susfs source + header files into kernel tree..."
mkdir -p include/linux
cp -v "$SUSFS_DIR/include/linux/susfs.h"     include/linux/susfs.h
cp -v "$SUSFS_DIR/include/linux/susfs_def.h" include/linux/susfs_def.h
cp -v "$SUSFS_DIR/include/linux/sus_su.h"    include/linux/sus_su.h
cp -v "$SUSFS_DIR/fs/susfs.c"                fs/susfs.c
cp -v "$SUSFS_DIR/fs/sus_su.c"               fs/sus_su.c 2>/dev/null || true
test -f fs/susfs.c
echo "[2d] OK: susfs.h + susfs_def.h + sus_su.h + fs/susfs.c staged"

# --- step 4b: register susfs.c in fs/Makefile (patch doesn't add obj-y) ---
# The 0001 patch adds C function hooks in fs/*.c but doesn't touch the
# Makefile, so the susfs code never gets compiled. Append obj-y entries
# so susfs.o + sus_su.o get linked into vmlinux.
echo "[2d+] Adding susfs.o + sus_su.o to fs/Makefile..."
if ! grep -q "susfs.o" fs/Makefile; then
  printf "\n# SUSFS (KernelSU addon)\nobj-y +=\tsusfs.o\n" >> fs/Makefile
fi
if [ -f fs/sus_su.c ] && ! grep -q "sus_su.o" fs/Makefile; then
  printf "obj-y +=\tsus_su.o\n" >> fs/Makefile
fi
grep -E "susfs\.o|sus_su\.o" fs/Makefile | head -5

# --- step 5: KSU Next susfs integration ---
# SKIP 0002-enable-susfs-ksu.patch — KSU Next v3.1.0-legacy-susfs already
# has CONFIG_KSU_SUSFS Kconfig + ifdefs built in. The ShirkNeko/susfs4ksu
# 0002 patch targets the older tiann/KernelSU API (core_hook.c, etc.)
# which doesn't exist in v3.1.0-legacy-susfs (renamed to lsm_hooks.c,
# setuid_hook.c, syscall_hook_manager.c, etc.). The Kconfig + ifdef
# integration is already present at this tag — nothing to apply.
echo "[2e] Skipping 0002 (KSU v3.1.0-legacy-susfs already has CONFIG_KSU_SUSFS)..."

# Sanity: KSU's Kconfig should expose KSU_SUSFS options natively
grep -q "config KSU_SUSFS" drivers/kernelsu/Kconfig || {
  echo "[2e] MISSING KSU_SUSFS in drivers/kernelsu/Kconfig"; exit 1; }

echo "[2] All patches applied successfully"
