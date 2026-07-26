#!/usr/bin/env bash
# Package the kernel image into an AnyKernel3 zip.
# Direct layout: KERNEL_SRC == KERNEL_DIR (no private/msm-google/).
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
OUT_DIR="${OUT_DIR:-out}"
AK3_DIR="${AK3_DIR:-anykernel3}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BOOT="$REPO_ROOT/$KERNEL_DIR/$OUT_DIR/arch/arm64/boot"
KERNEL_IMAGE=""
for img in \
  "$BOOT/Image.gz-dtb" \
  "$BOOT/Image.lz4-dtb" \
  "$BOOT/Image"; do
  if [ -f "$img" ]; then
    KERNEL_IMAGE="$img"
    echo "[6] Found: $KERNEL_IMAGE"
    break
  fi
done

if [ -z "$KERNEL_IMAGE" ]; then
  echo "[6] ERROR: No kernel image found in $BOOT"; exit 1
fi

echo "[6] Cleaning stale images from AK3 dir"
rm -f "$REPO_ROOT/$AK3_DIR"/Image* "$REPO_ROOT/$AK3_DIR"/dtbo.img "$REPO_ROOT/$AK3_DIR"/dtb

cp "$KERNEL_IMAGE" "$REPO_ROOT/$AK3_DIR/"

if [ -f "$BOOT/dtbo.img" ]; then
  cp "$BOOT/dtbo.img" "$REPO_ROOT/$AK3_DIR/"
  echo "[6] dtbo.img copied"
fi

cd "$REPO_ROOT/$AK3_DIR"
ZIP="$REPO_ROOT/AnyKernel3-coral-$(date +%Y%m%d).zip"
rm -f "$ZIP"
zip -r9 "$ZIP" . -x "*.DS_Store" "*.log"
echo "[6] Zip: $ZIP"
ls -lh "$ZIP"