#!/usr/bin/env bash
# Build the kernel.
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabihf-
export CC="ccache aarch64-linux-gnu-gcc"

cd kernel

echo "[4] gcc version:"
aarch64-linux-gnu-gcc --version | head -1

# Freeze mtime of all autoconf headers so top Makefile is NOT regenerated
# during the build. 4.14 + O=out + multi-job gets into silentoldconfig
# infinite loop because each subdir touches auto.conf.cmd, then the top
# Makefile is regenerated, then each subdir re-runs silentoldconfig, …
# Touching everything in include/config to a fixed past time breaks the
# dependency cycle. The config is already finalised in 3-configure.sh.
echo "[4] Freezing include/config mtimes to break silentoldconfig loop..."
if [ -d "$OUT_DIR/include/config" ]; then
  find "$OUT_DIR/include/config" -type f -exec touch -d "2000-01-01 00:00:00" {} +
fi

START=$(date +%s)
echo "[4] Starting build at $(date)"

make O="$OUT_DIR" -j"$(nproc)" \
  ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
  Image.gz-dtb 2>&1 | tee ../build.log

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