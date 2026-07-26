#!/usr/bin/env bash
# Run KSU Next setup.sh for legacy branch.
# Note: susfs kernel-tree patches (include/linux/susfs.h, fs/susfs.c,
# etc.) from devnoname120/susfs4ksu-toco do NOT apply cleanly to
# coral's android-msm-coral-4.14-android10-qpr3 source (hunk
# mismatches in fs/namei.c, fs/notify/fdinfo.c, fs/proc/cmdline.c,
# fs/proc/task_mmu.c — coral has different offsets). Disabling
# CONFIG_KSU_SUSFS in defconfig so the '#include <linux/susfs.h>' in
# drivers/kernelsu/ksu.c:17 is never activated. KSU itself still
# works without susfs.
set -euo pipefail

KSU_TAG="${KSU_TAG:-v3.1.0-legacy}"
KSU_SETUP_URL="${KSU_SETUP_URL:-https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh}"

KERNEL_DIR="${KERNEL_DIR:-kernel}"
KERNEL_SRC="$KERNEL_DIR/private/msm-google"

cd "$KERNEL_SRC"

echo "[1] Running KSU Next setup for tag: $KSU_TAG"
curl -LSs "$KSU_SETUP_URL" | bash -s "$KSU_TAG"

echo "[1] Verifying KSU integration..."
if [ ! -e drivers/kernelsu ]; then
  echo "[1] ERROR: drivers/kernelsu missing"; exit 1
fi
grep -q "kernelsu/" drivers/Makefile || { echo "[1] drivers/Makefile missing ksu obj"; exit 1; }
grep -q "kernelsu/Kconfig" drivers/Kconfig || { echo "[1] drivers/Kconfig missing ksu source"; exit 1; }

echo "[1] OK: KSU integrated (susfs disabled via defconfig fragment)"
ls drivers/kernelsu/ | head -15
