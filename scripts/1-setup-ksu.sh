#!/usr/bin/env bash
# Setup KSU Next from sidex15 fork (legacy-susfs-v2 branch).
# sidex15's setup.sh hardcodes OWNER="KernelSU-Next" — we patch it to sidex15
# before piping into bash.
#
# Why sidex15 fork: upstream KSU Next `next` branch / `v3.1.0-legacy-susfs` tag
# has its own in-module susfs surface (kernel_umount.c, su_mount_ns.c) that
# doesn't pair cleanly with the simonpunk susfs4ksu kernel-4.14 patch series.
# sidex15 maintains `legacy-susfs-v2` which is the matching branch for simonpunk.
#
# 4.14 msm lacks HAVE_SYSCALL_TRACEPOINTS so kprobes mode is unavailable;
# we apply manual hooks via patches/ksu-manual-hooks/ in 2-apply-patches.sh.
set -euo pipefail

KSU_OWNER="${KSU_OWNER:-sidex15}"
KSU_TAG="${KSU_TAG:-legacy-susfs-v2}"
KSU_SETUP_URL="${KSU_SETUP_URL:-https://raw.githubusercontent.com/${KSU_OWNER}/KernelSU-Next/next/kernel/setup.sh}"

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"

cd "$KERNEL_SRC"

echo "[1] Running KSU setup for ${KSU_OWNER}/KernelSU-Next @ ${KSU_TAG}"
# Fetch sidex15 setup.sh, patch OWNER to sidex15 (it hardcodes KernelSU-Next).
TMP_SETUP=$(mktemp)
curl -LSs "$KSU_SETUP_URL" -o "$TMP_SETUP"
# Replace OWNER="KernelSU-Next" with sidex15 (or whatever KSU_OWNER is).
sed -i.bak "s|^OWNER=.*|OWNER=\"${KSU_OWNER}\"|" "$TMP_SETUP"
bash "$TMP_SETUP" "$KSU_TAG"
rm -f "$TMP_SETUP" "$TMP_SETUP.bak"

echo "[1] Verifying KSU integration..."
if [ ! -e drivers/kernelsu ]; then
  echo "[1] ERROR: drivers/kernelsu missing"; exit 1
fi
grep -q "kernelsu/" drivers/Makefile || { echo "[1] drivers/Makefile missing ksu obj"; exit 1; }
grep -q "kernelsu/Kconfig" drivers/Kconfig || { echo "[1] drivers/Kconfig missing ksu source"; exit 1; }

echo "[1] OK: KSU integrated (sidex15/${KSU_TAG}, manual hooks)"
ls drivers/kernelsu/ | head -15