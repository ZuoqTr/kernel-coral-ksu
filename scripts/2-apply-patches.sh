#!/usr/bin/env bash
# Apply 5 KSU manual hook patches to the kernel tree.
# Script runs from REPO_ROOT (workflow working-directory).
# KERNEL_DIR/kernel-source = $KERNEL_DIR/private/msm-google,
# so patches at $REPO_ROOT/patches are reached by ../../../patches/
# (repo-root -> kernel-build -> kernel -> private/msm-google).
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
KERNEL_SRC="$KERNEL_DIR/private/msm-google"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$KERNEL_SRC"

for p in "$REPO_ROOT/patches/ksu-manual-hooks/"*.patch; do
  echo "[2] Applying $(basename "$p")"
  if ! git apply --verbose "$p"; then
    echo "[2] Retrying with --ignore-whitespace"
    git apply --verbose --ignore-whitespace "$p" || { echo "[2] FAIL: $p"; exit 1; }
  fi
done

echo "[2] Verifying hooks present:"
for f in fs/exec.c fs/open.c fs/read_write.c fs/stat.c kernel/reboot.c; do
  if grep -q "ksu_handle_" "$f"; then
    echo "  $f: OK"
  else
    echo "  $f: MISSING ksu_handle_"
    exit 1
  fi
done