#!/usr/bin/env bash
# Direct kernel build via make. Clang 12 (r416183b) + Apt GCC 4.9 (compiler).
# kprobes mode KSU - no manual hooks, no build.sh wrapper, no manifest.
# Matches devnoname120/tocoksu + EdgeTDR kernel-builder pattern.
#
# Clang 12 from kernel-build/clang-r416183b/bin (fetched by 0b-fetch-clang.sh)
# aarch64-linux-android-4.9 (KudProject fork, has gcc compiler) for cross
# aarch64-linux-gnu- from apt (gcc-aarch64-linux-gnu) as fallback if needed
#
# Direct kernel source layout: $KERNEL_DIR/ == kernel root.
#
# Why LLVM=0: kernel Makefile forces HOSTCC=clang when LLVM=1. Clang 12
# defaults to -fno-common which breaks flex/bison-generated dtc link
# (yylloc defined in both dtc-parser.tab.o and dtc-lexer.lex.o). With
# LLVM=0, kernel Makefile uses apt gcc for host tools (gcc 11.4 defaults
# to -fcommon) and all dtc flex/bison TUs link cleanly. CC=clang still
# applies to cross-compile (kernel image).
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
OUT_DIR="${OUT_DIR:-out}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
CLANG_DIR="$REPO_ROOT/kernel-build/clang-r416183b"
GCC_AARCH64_DIR="$REPO_ROOT/kernel-build/prebuilts/aarch64-linux-android-4.9"
GCC_ARM_DIR="$REPO_ROOT/kernel-build/prebuilts/arm-linux-androideabi-4.9"

if [ ! -x "$CLANG_DIR/bin/clang" ]; then
  echo "[4] ERROR: $CLANG_DIR/bin/clang missing; run 0b-fetch-clang.sh first"
  exit 1
fi

if [ ! -x "$GCC_AARCH64_DIR/bin/aarch64-linux-android-gcc" ]; then
  echo "[4] ERROR: GCC 4.9 aarch64 missing; run 0c-fetch-gcc.sh first"
  exit 1
fi

# Clang 12 on PATH (cross compile). AOSP GCC 4.9 binutils on PATH
# (LLVM/Clang 12 link uses ld.bfd from aarch64-linux-android-4.9 for
# LSE atomics + .inst handling). Apt gcc on PATH for HOSTCC.
export PATH="$CLANG_DIR/bin:$GCC_AARCH64_DIR/bin:$GCC_ARM_DIR/bin:/usr/bin:/usr/bin/aarch64-linux-gnu:$PATH"
export CC="clang"
export CXX="clang++"
# Apt gcc for HOSTCC (kernel Makefile picks this when LLVM=0).
export HOSTCC="gcc"
export HOSTCXX="g++"

# Kernel make vars. LLVM=0 forces apt gcc for host tools (dtc, etc).
# CC=clang still applies to cross-compile.
export ARCH=arm64
export CROSS_COMPILE="aarch64-linux-android-"
export CROSS_COMPILE_ARM32="arm-linux-androideabi-"
export LLVM=0
export LLVM_IAS=0
# Clang + Android triple. 4.14 msm Makefile:496 requires CLANG_TRIPLE
# when CC=clang. Triples differ from CROSS_COMPILE prefix (linux-gnu
# not linux-android) because the kernel uses GNU target not bionic.
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CLANG_GCC_TRIPLE="aarch64-linux-gnu-"
export O="$KERNEL_SRC/$OUT_DIR"

cd "$KERNEL_SRC"

# Apply EXTRAVERSION suffix (e.g. -KSU-SUSFS-coral) to kernel version.
# Workflow input defaults to -KSU-SUSFS-coral. KSU Next also adds its
# own suffix internally; final uname -r = <ver>-KSU-<extra>-KSU.
EXTRAVERSION="${EXTRAVERSION:--KSU-SUSFS-coral}"
if ! grep -q "^EXTRAVERSION" Makefile; then
  echo "EXTRAVERSION = ${EXTRAVERSION}" >> Makefile
  echo "[4] EXTRAVERSION appended: ${EXTRAVERSION}"
else
  echo "[4] EXTRAVERSION already set in Makefile (KSU Next default)"
fi

START=$(date +%s)
echo "[4] build start: $(date)"
echo "[4] CC: $CC"
echo "[4] HOSTCC: $HOSTCC"
echo "[4] CROSS_COMPILE: $CROSS_COMPILE"
echo "[4] LLVM: $LLVM"
echo "[4] KERNEL_SRC: $KERNEL_SRC"
echo "[4] O: $O"

# Direct make invocation. -j parallel, ARCH=arm64, LLVM=0 (apt gcc for
# host). CC=clang still applies to cross-compile.
make -j"$(nproc)" \
  ARCH=arm64 \
  CC=clang \
  HOSTCC=gcc \
  HOSTCXX=g++ \
  HOSTCFLAGS="-fcommon" \
  HOSTLDFLAGS="-Wl,--allow-multiple-definition" \
  CROSS_COMPILE=aarch64-linux-android- \
  CROSS_COMPILE_ARM32=arm-linux-androideabi- \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CLANG_GCC_TRIPLE=aarch64-linux-gnu- \
  LLVM=0 \
  LLVM_IAS=0 \
  O="$O" \
  Image.gz-dtb \
  2>&1 | tee "$REPO_ROOT/$KERNEL_DIR/build.log"

END=$(date +%s)
echo "[4] Build duration: $(((END-START)/60))m $(((END-START)%60))s"

BOOT="$O/arch/arm64/boot"
echo "[4] Built images:"
ls -lh "$BOOT" 2>/dev/null | grep -E "Image|dtb|dtbo" || true

for img in Image.gz-dtb Image.lz4-dtb Image; do
  if [ -f "$BOOT/$img" ]; then
    echo "[4] SUCCESS: $img at $BOOT/$img"
    exit 0
  fi
done
echo "[4] ERROR: no kernel image produced"
exit 1
