#!/usr/bin/env bash
# Build kernel using Clang as the compiler driver + AOSP GCC 4.9
# prebuilt as the linker/libs. The LLVM=1 / LLVM_IAS=1 flags tell
# 4.14 msm's build system to take Clang-specific paths (asm-generic,
# etc.). GCC 4.9 is used because it predates the -Werror/array-bounds
# tightening that GCC 11/12 added against 4.14 arm64 inline asm.
#
# HOSTCFLAGS=-fcommon: GCC 10+ defaults to -fno-common; 4.14 dtc
# has yylloc in two TUs. -fcommon merges into single common storage.
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"
GCC_64_DIR="${GCC_64_DIR:-${GITHUB_WORKSPACE:-$(pwd)/..}/gcc-64}"
GCC_32_DIR="${GCC_32_DIR:-${GITHUB_WORKSPACE:-$(pwd)/..}/gcc-32}"

export ARCH=arm64
export CROSS_COMPILE="$GCC_64_DIR/bin/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="$GCC_32_DIR/bin/arm-linux-androideabi-"

export CC="clang"
export CXX="clang++"
export LD="ld.lld"
export AR="llvm-ar"
export NM="llvm-nm"
export OBJCOPY="llvm-objcopy"
export OBJDUMP="llvm-objdump"
export STRIP="llvm-strip"
export READELF="llvm-readelf"
export HOSTCC=clang
export HOSTCXX="clang++"

export LLVM=1
export LLVM_IAS=1
export CLANG_TRIPLE=aarch64-linux-gnu-

cd "$KERNEL_DIR"

echo "[4] Clang: $(clang --version | head -1)"
echo "[4] GCC 4.9 (64-bit): $(${CROSS_COMPILE}gcc --version | head -1)"
echo "[4] GCC 4.9 (32-bit): $(${CROSS_COMPILE_ARM32}gcc --version 2>/dev/null | head -1 || echo 'N/A')"

START=$(date +%s)
echo "[4] Starting build at $(date)"

make -j"$(nproc)" \
  O="$OUT_DIR" \
  ARCH=arm64 \
  CROSS_COMPILE="$CROSS_COMPILE" \
  CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
  HOSTCFLAGS="-fcommon" \
  KBUILD_HOSTCFLAGS="-fcommon" \
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