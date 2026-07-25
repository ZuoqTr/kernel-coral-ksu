#!/usr/bin/env bash
# Build the kernel.
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC="ccache aarch64-linux-gnu-gcc"

cd kernel

echo "[4] gcc version:"
aarch64-linux-gnu-gcc --version | head -1

START=$(date +%s)
echo "[4] Starting build at $(date)"

make O="$OUT_DIR" -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz-dtb 2>&1 | tee ../build.log

END=$(date +%s)
echo "[4] Build duration: $(((END-START)/60))m $(((END-START)%60))s"

echo "[4] Built images:"
ls -lh "$OUT_DIR/arch/arm64/boot/" | grep -E "Image|dtb|dtbo" || true

if [ -f "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" ]; then
  echo "[4] SUCCESS: Image.gz-dtb present"
elif [ -f "$OUT_DIR/arch/arm64/boot/Image.lz4-dtb" ]; then
  echo "[4] SUCCESS: Image.lz4-dtb present (LZ4)"
elif [ -f "$OUT_DIR/arch/arm64/boot/Image" ]; then
  echo "[4] SUCCESS: Image present (raw)"
else
  echo "[4] ERROR: No kernel image built"
  exit 1
fi