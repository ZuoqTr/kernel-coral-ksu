#!/usr/bin/env bash
# Apply KernelSU Next manual-hooks patches.
# v3.1.0-legacy branch uses manual hooks (no kprobes, 4.14 msm lacks
# HAVE_SYSCALL_TRACEPOINTS). Five kernel syscall sites get ksu_handle_*
# call insertions, gated on CONFIG_KSU.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
PATCH_DIR="$REPO_ROOT/patches/ksu-manual-hooks"

cd "$KERNEL_SRC"

echo "[2] Applying KSU Next manual-hooks patches..."
for p in "$PATCH_DIR"/*.patch; do
  echo "[2]   $p"
  git apply --verbose "$p" || {
    echo "[2] FAILED: $p"
    git apply --verbose --ignore-whitespace "$p" || exit 1
  }
done

echo "[2] Verifying hooks inserted..."
for f in fs/exec.c fs/open.c fs/read_write.c fs/stat.c kernel/reboot.c; do
  if ! grep -q "ksu_handle_" "$f"; then
    echo "[2] MISSING hooks in $f"; exit 1
  fi
done
echo "[2] OK: all 5 manual hooks applied"
