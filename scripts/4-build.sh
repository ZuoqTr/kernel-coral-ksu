#!/usr/bin/env bash
# Build kernel using AOSP GCC 4.9 (android12L-release branch).
# 4.14 msm kernel was originally built against this toolchain.
# Clang 14 hits two hard errors that 4.9 doesn't:
#   - -mgeneral-regs-only incompatible with float types in
#     drivers/power/supply/google/google_charger.c (logbuffer_log
#     macro uses %f format spec)
#   - __bad_copy_to size mismatch in drivers/platform/msm/ipa
# GCC 4.9 predates these checks; Clang considered but rejected.
#
# HOSTCFLAGS=-fcommon: GCC 10+ defaults to -fno-common; 4.14 dtc has
# yylloc in two TUs. -fcommon merges into single common storage.
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"
GCC_64_DIR="${GCC_64_DIR:-$GITHUB_WORKSPACE/gcc-64}"
GCC_32_DIR="${GCC_32_DIR:-$GITHUB_WORKSPACE/gcc-32}"

if [ ! -x "$GCC_64_DIR/bin/aarch64-linux-android-gcc" ]; then
  echo "[4] ERROR: GCC 4.9 64-bit not at $GCC_64_DIR/bin/aarch64-linux-android-gcc"
  exit 1
fi
if [ ! -x "$GCC_32_DIR/bin/arm-linux-androideabi-gcc" ]; then
  echo "[4] ERROR: GCC 4.9 32-bit not at $GCC_32_DIR/bin/arm-linux-androideabi-gcc"
  exit 1
fi

export ARCH=arm64
export CROSS_COMPILE="$GCC_64_DIR/bin/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="$GCC_32_DIR/bin/arm-linux-androideabi-"

export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"
export LD="${CROSS_COMPILE}ld"
export AR="${CROSS_COMPILE}ar"
export NM="${CROSS_COMPILE}nm"
export OBJCOPY="${CROSS_COMPILE}objcopy"
export OBJDUMP="${CROSS_COMPILE}objdump"
export STRIP="${CROSS_COMPILE}strip"
export READELF="${CROSS_COMPILE}readelf"
export HOSTCC=gcc
export HOSTCXX=g++

unset LLVM LLVM_IAS CLANG_TRIPLE

cd "$KERNEL_DIR"

echo "[4] GCC 4.9: $($CC --version | head -1)"
echo "[4] GCC 4.9 32-bit: $($CROSS_COMPILE_ARM32$CC --version | head -1)"

START=$(date +%s)
echo "[4] Starting build at $(date)"

# GCC 4.9 doesn't have -Wno-error=array-bounds kind of issues that
# gcc 11+ has. -Werror is harmless here. No -idirafter needed (4.9
# uses its own limits.h via $GCC_64_DIR/$GCC_32_DIR sysroot).
KCFLAGS="-Wno-error"

# Build target: 'Image' (no dtbs). Image.gz-dtb pulls in DTBO/DTS
# preprocessing which adds overhead. AK3 on device concatenates
# vendor ramdisk DTBs.
make -j"$(nproc)" \
  O="$OUT_DIR" \
  ARCH=arm64 \
  CROSS_COMPILE="$CROSS_COMPILE" \
  CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
  HOSTCFLAGS="-fcommon" \
  KBUILD_HOSTCFLAGS="-fcommon" \
  KCFLAGS="$KCFLAGS" \
  Image 2>&1 | tee ../build.log

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
