#!/usr/bin/env bash
# Apply 5 KSU manual hook patches to the kernel tree.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
KERNEL_SRC="$KERNEL_DIR/private/msm-google"

cd "$KERNEL_SRC"

for p in ../../patches/ksu-manual-hooks/*.patch; do
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