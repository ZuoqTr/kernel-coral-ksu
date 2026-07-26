#!/usr/bin/env bash
# Direct kernel build via make. Clang 12 (r416183b) + aarch64-linux-gnu
# cross. kprobes mode KSU — no manual hooks, no build.sh wrapper, no
# manifest. Matches devnoname120/tocoksu pattern.
#
# Clang 12 from kernel-build/clang-r416183b/bin (fetched by 0b-fetch-clang.sh)
# aarch64-linux-gnu- from apt (gcc-aarch64-linux-gnu)
#
# Direct kernel source layout: $KERNEL_DIR/ == kernel root.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
OUT_DIR="${OUT_DIR:-out}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
CLANG_DIR="$REPO_ROOT/kernel-build/clang-r416183b"

if [ ! -x "$CLANG_DIR/bin/clang" ]; then
  echo "[4] ERROR: $CLANG_DIR/bin/clang missing; run 0b-fetch-clang.sh first"
  exit 1
fi

# Clang 12 on PATH + aarch64 cross
export PATH="$CLANG_DIR/bin:/usr/bin:/usr/bin/aarch64-linux-gnu:$PATH"
export CC="clang"
export CXX="clang++"
export HOSTCC="clang"
export HOSTCXX="clang++"

# Kernel make vars
export ARCH=arm64
export CROSS_COMPILE="aarch64-linux-gnu-"
export LLVM=1
export LLVM_IAS=1
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
echo "[4] CROSS_COMPILE: $CROSS_COMPILE"
echo "[4] LLVM: $LLVM"
echo "[4] KERNEL_SRC: $KERNEL_SRC"
echo "[4] O: $O"

# Direct make invocation. -j parallel, ARCH=arm64, LLVM=1. NO build.sh
# wrapper (avoids all the silentoldconfig + check_defconfig issues from
# the manifest path).
make -j"$(nproc)" \
  ARCH=arm64 \
  CC=clang \
  CROSS_COMPILE=aarch64-linux-gnu- \
  LLVM=1 \
  LLVM_IAS=1 \
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