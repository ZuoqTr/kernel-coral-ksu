#!/usr/bin/env bash
# Build kernel using apt gcc-aarch64-linux-gnu (gcc 11/12). This was
# the original path before the Clang pivot. The Clang pivot hit
# hard errors specific to Clang 14 that gcc doesn't:
#   - -mgeneral-regs-only incompatible with float types in msm charger
#   - __bad_copy_to size mismatch in msm ipa
# gcc 11 hits a flood of -Werror=array-bounds/maybe-uninitialized/
# implicit-int/etc. warnings on 4.14 msm inline asm. Suppress ALL of
# those by appending -Wno-error to KCFLAGS — kbuild's -Werror becomes
# -Werror -Wno-error = effectively warnings-only.
#
# Clang apt install is kept as fallback for ld.lld (linker).
#
# HOSTCFLAGS=-fcommon: GCC 10+ defaults to -fno-common; 4.14 dtc has
# yylloc in two TUs. -fcommon merges into single common storage.
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabihf-

export CC="aarch64-linux-gnu-gcc"
export CXX="aarch64-linux-gnu-g++"
export LD="aarch64-linux-gnu-ld"
export AR="aarch64-linux-gnu-ar"
export NM="aarch64-linux-gnu-nm"
export OBJCOPY="aarch64-linux-gnu-objcopy"
export OBJDUMP="aarch64-linux-gnu-objdump"
export STRIP="aarch64-linux-gnu-strip"
export READELF="aarch64-linux-gnu-readelf"
export HOSTCC=gcc
export HOSTCXX=g++

unset LLVM LLVM_IAS CLANG_TRIPLE

cd "$KERNEL_DIR"

echo "[4] GCC: $($CC --version | head -1)"
echo "[4] CROSS_COMPILE_ARM32: $(${CROSS_COMPILE_ARM32}gcc --version | head -1)"

START=$(date +%s)
echo "[4] Starting build at $(date)"

# KCFLAGS=-Wno-error suppresses -Werror from KBUILD_CFLAGS_KERNEL.
# The kbuild's -Werror sits before KCFLAGS so -Wno-error after it
# cancels the error elevation. The remaining -Wno-error=* entries
# below target Clang-specific false positives that don't apply to
# gcc but won't hurt.
KCFLAGS="-Wno-error -Wno-error=array-bounds -Wno-error=maybe-uninitialized -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=stringop-overflow -Wno-error=stringop-overread -Wno-error=address-of-packed-member -Wno-error=cast-function-type -Wno-error=enum-conversion -Wno-error=stringop-truncation -idirafter /usr/aarch64-linux-gnu/include -idirafter /usr/arm-linux-gnueabihf/include"

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