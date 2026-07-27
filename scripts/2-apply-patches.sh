#!/usr/bin/env bash
# Apply KernelSU Next manual hooks. Susfs4ksu kernel patch is SKIPPED.
#
# Order:
#  1. Setup KSU (handled by 1-setup-ksu.sh — creates drivers/kernelsu symlink)
#  2. Apply 5 manual-hooks patches (ksu_handle_* externs + calls in syscall sites)
#
# Susfs4ksu kernel patch (patches/susfs-kernel-4.14/0001-combined.patch) is
# SKIPPED because it was authored against a post-4.18 IDA-API kernel and
# does not apply cleanly to this 4.14 msm source (which uses pre-4.18
# ida_pre_get/ida_get_new_above/ida_remove). Since CONFIG_KSU_SUSFS is
# disabled in ksu-susfs.config, the in-tree susfs_* externs are not
# referenced and the kernel links cleanly without those patches.
#
# KSU Next v3.1.0-legacy-susfs ships its own in-module susfs v2.0.0
# implementation (kernel_umount.c, su_mount_ns.c, etc.). Enabling
# CONFIG_KSU_SUSFS would require a correctly-anchored patch series —
# the patches/susfs-kernel-4.14/0001-combined.patch would need to be
# regenerated against the actual msm-4.14 IDA API first.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
HOOK_DIR="$REPO_ROOT/patches/ksu-manual-hooks"

cd "$KERNEL_SRC"

# --- step 1: setup KSU (handled by 1-setup-ksu.sh before this script) ---
echo "[2a] Verifying drivers/kernelsu symlink exists..."
test -e drivers/kernelsu || { echo "drivers/kernelsu missing — did 1-setup-ksu.sh run?"; exit 1; }
grep -q "kernelsu/" drivers/Makefile
grep -q "kernelsu/Kconfig" drivers/Kconfig

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

# --- step 3: susfs kernel patch SKIPPED ---
# Disabled: see header comment. If re-enabled, also re-enable step 2f
# (compat_fillonedir fixup) and the fs/susfs.c copy + Makefile entries.
echo "[2c] SKIPPING susfs kernel patch (CONFIG_KSU_SUSFS=n)"

# --- step 4: SUSFS integration in KSU (KSU Next handles in-module) ---
echo "[2d] KSU Next v3.1.0-legacy-susfs ships in-module susfs — no separate copy needed"

# --- step 5: sanity ---
grep -q "config KSU_SUSFS" drivers/kernelsu/Kconfig || {
  echo "[2e] MISSING KSU_SUSFS in drivers/kernelsu/Kconfig"; exit 1; }

echo "[2] All patches applied successfully (KSU-only, susfs disabled)"