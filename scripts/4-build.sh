#!/usr/bin/env bash
# Build kernel O=out (matches 3-configure.sh).
# Uses -j`nproc` for compile parallelism but serializes the kconfig
# pattern rule at Makefile:619 by running `make -j1 prepare0` first.
# Running prepare0 alone writes include/config/auto.conf.cmd with a
# mtime >= auto.conf, after which the recursive silentoldconfig loop
# stops firing when the real build's pattern rule evaluation runs.
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabihf-
export CC="ccache aarch64-linux-gnu-gcc"

cd kernel

echo "[4] gcc version:"
aarch64-linux-gnu-gcc --version | head -1

# Step 1: settle kconfig state with a single-threaded prepare0. This
# writes include/config/auto.conf.cmd with a stable mtime so that the
# pattern rule at Makefile:619 sees a satisfied prereq and does not
# re-fire when the parallel build starts.
echo "[4] make -j1 O=out prepare0 (kconfig settle)"
make -j1 O="$OUT_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- prepare0 2>&1 | tail -10

# Force auto.conf to be "newer" than its dependencies for Make's
# pattern rule. This is the documented workaround for the 4.14
# silentoldconfig loop: tell make the file was just updated.
echo "[4] mark auto.conf.cmd as newer than auto.conf"
touch "$OUT_DIR/include/config/auto.conf" "$OUT_DIR/include/config/auto.conf.cmd" \
      "$OUT_DIR/include/config/tristate.conf"

START=$(date +%s)
echo "[4] Starting parallel build at $(date)"

# Step 2: real parallel build. The Makefile:619 pattern rule will
# short-circuit because auto.conf.cmd is now strictly newer than
# auto.conf, satisfying the %: prereq order.
make -j"$(nproc)" \
  O="$OUT_DIR" \
  ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
  Image.gz-dtb 2>&1 | tee ../build.log

END=$(date +%s)
echo "[4] Build duration: $(((END-START)/60))m $(((END-START)%60))s"

BOOT="$OUT_DIR/arch/arm64/boot"
echo "[4] Built images:"
ls -lh "$BOOT" | grep -E "Image|dtb|dtbo" || true

if [ -f "$BOOT/Image.gz-dtb" ]; then
  echo "[4] SUCCESS: Image.gz-dtb present"
elif [ -f "$BOOT/Image.lz4-dtb" ]; then
  echo "[4] SUCCESS: Image.lz4-dtb present (LZ4)"
elif [ -f "$BOOT/Image" ]; then
  echo "[4] SUCCESS: Image present (raw)"
else
  echo "[4] ERROR: No kernel image built"
  exit 1
fi
