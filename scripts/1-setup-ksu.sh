#!/usr/bin/env bash
# 1. Run KSU Next setup.sh for legacy branch + susfs tag.
# 2. Apply the susfs4ksu kernel-tree patches (include/linux/susfs.h,
#    fs/susfs.c, etc.) so KSU's #include <linux/susfs.h> resolves.
set -euo pipefail

KSU_TAG="${KSU_TAG:-v3.1.0-legacy-susfs}"
KSU_SETUP_URL="${KSU_SETUP_URL:-https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh}"

# devnoname120/susfs4ksu-toco branch kernel-4.14-backport ships the
# kernel-tree patches for 4.14. KSU Next's "legacy-susfs" tag is
# built against a kernel that has these patches pre-applied; we
# apply them after KSU setup.
SUSFS_REPO="${SUSFS_REPO:-https://github.com/devnoname120/susfs4ksu-toco.git}"
SUSFS_BRANCH="${SUSFS_BRANCH:-kernel-4.14-backport}"

cd kernel

echo "[1] Running KSU Next setup for tag: $KSU_TAG"
curl -LSs "$KSU_SETUP_URL" | bash -s "$KSU_TAG"

echo "[1] Verifying KSU integration..."
if [ ! -e drivers/kernelsu ]; then
  echo "[1] ERROR: drivers/kernelsu missing"; exit 1
fi
grep -q "kernelsu/" drivers/Makefile || { echo "[1] drivers/Makefile missing ksu obj"; exit 1; }
grep -q "kernelsu/Kconfig" drivers/Kconfig || { echo "[1] drivers/Kconfig missing ksu source"; exit 1; }

echo "[1] Applying susfs4ksu kernel-tree patches (branch: $SUSFS_BRANCH)..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
git clone --depth=1 --branch "$SUSFS_BRANCH" "$SUSFS_REPO" "$WORK/susfs4ksu"
SUSFS_ROOT="$WORK/susfs4ksu"

# Apply kernel-tree patches (include/linux/susfs.h + fs/susfs.c + ...)
if [ -d "$SUSFS_ROOT/kernel_patches" ]; then
  # 1) drop-in include/linux/*.h (susfs.h, susfs_def.h, sus_su.h)
  if [ -d "$SUSFS_ROOT/kernel_patches/include/linux" ]; then
    cp -av "$SUSFS_ROOT/kernel_patches/include/linux/"*.h include/linux/
    echo "[1] copied susfs include headers to include/linux/"
  fi
  # 2) drop-in fs/*.c (susfs.c, sus_su.c)
  if [ -d "$SUSFS_ROOT/kernel_patches/fs" ]; then
    cp -av "$SUSFS_ROOT/kernel_patches/fs/"*.c fs/ 2>/dev/null || true
    echo "[1] copied susfs fs sources to fs/"
  fi
  # 3) apply the patch series that wires them in (Kconfig, Makefile,
  #    syscall hooks, etc.)
  if [ -f "$SUSFS_ROOT/kernel_patches/50_add_susfs_in_kernel-4.14.patch" ]; then
    git apply --check "$SUSFS_ROOT/kernel_patches/50_add_susfs_in_kernel-4.14.patch" \
      || { echo "[1] ERROR: 50_add_susfs_in_kernel-4.14.patch does not apply"; exit 1; }
    git apply "$SUSFS_ROOT/kernel_patches/50_add_susfs_in_kernel-4.14.patch"
    echo "[1] applied 50_add_susfs_in_kernel-4.14.patch"
  fi
  # 4) KSU-side enable patch (registers susfs_init + hook list)
  if [ -f "$SUSFS_ROOT/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" ]; then
    # this patch is relative to KernelSU/ subdir; we apply to drivers/kernelsu/
    pushd drivers/kernelsu > /dev/null
    if git apply --check "$SUSFS_ROOT/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" 2>/dev/null; then
      git apply "$SUSFS_ROOT/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"
      echo "[1] applied 10_enable_susfs_for_ksu.patch"
    else
      echo "[1] WARN: 10_enable_susfs_for_ksu.patch does not apply cleanly, skipping"
    fi
    popd > /dev/null
  fi
else
  echo "[1] ERROR: $SUSFS_ROOT/kernel_patches not found"
  exit 1
fi

echo "[1] Verify susfs.h present:"
ls -la include/linux/susfs*.h include/linux/sus_su.h 2>&1 | head -5
echo "[1] Verify susfs.c present:"
ls -la fs/susfs.c fs/sus_su.c 2>&1 | head -5

echo "[1] OK: KSU + susfs integrated"
ls drivers/kernelsu/ | head -15