#!/usr/bin/env bash
# Run KSU Next setup.sh for legacy branch (manual hooks).
# v3.1.0-legacy-susfs: tag with susfs hooks pre-merged + manual-hooks only.
# 4.14 msm lacks HAVE_SYSCALL_TRACEPOINTS so kprobes mode is unavailable;
# we apply manual hooks via patches/ksu-manual-hooks/ in 2-apply-patches.sh.
set -euo pipefail

KSU_TAG="${KSU_TAG:-v3.1.0-legacy-susfs}"
KSU_SETUP_URL="${KSU_SETUP_URL:-https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh}"

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"

cd "$KERNEL_SRC"

echo "[1] Running KSU Next setup for tag: $KSU_TAG"
curl -LSs "$KSU_SETUP_URL" | bash -s "$KSU_TAG"

echo "[1] Verifying KSU integration..."
if [ ! -e drivers/kernelsu ]; then
  echo "[1] ERROR: drivers/kernelsu missing"; exit 1
fi
grep -q "kernelsu/" drivers/Makefile || { echo "[1] drivers/Makefile missing ksu obj"; exit 1; }
grep -q "kernelsu/Kconfig" drivers/Kconfig || { echo "[1] drivers/Kconfig missing ksu source"; exit 1; }

echo "[1] OK: KSU integrated (manual hooks, tag $KSU_TAG)"
ls drivers/kernelsu/ | head -15