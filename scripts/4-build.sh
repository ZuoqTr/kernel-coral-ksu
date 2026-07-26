#!/usr/bin/env bash
# Build kernel via AOSP build.sh (pinned in manifest at build/build.sh).
# build.sh reads BUILD_CONFIG = build.config (= build.config.no-cfi
# linkfile, per manifest). It sets up Clang + GCC 4.9 cross-compile via
# the pinned prebuilts and drives make with the right LLVM=1 flags.
# This is the canonical AOSP kernel build flow — sidesteps all the
# source-level hard errors we hit with apt gcc-11 / apt clang-14 /
# Clang-12 tarball orchestration.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
OUT_DIR="${OUT_DIR:-out}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR/private/msm-google"
BUILD_SH="$REPO_ROOT/$KERNEL_DIR/build/build.sh"

if [ ! -x "$BUILD_SH" ]; then
  echo "[4] ERROR: $BUILD_SH not found; run 0-prep-kernel.sh first"
  exit 1
fi

# build.sh's _setup_env.sh does `export ROOT_DIR=$PWD` — overwrites the
# ROOT_DIR that build.sh set from $(dirname $0). So PWD at the moment
# _setup_env.sh runs MUST be the manifest root (the dir holding build.config
# symlink + private/ + prebuilts*/), not the kernel source dir.
# The build.config symlink at kernel/build.config ->
# private/msm-google/build.config.no-cfi is what makes this work; the
# KERNEL_DIR=private/msm-google line inside the .no-cfi file expands relative
# to the cwd's ROOT_DIR.
cd "$REPO_ROOT/$KERNEL_DIR"

# ccache wrap
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.cache/ccache}"
mkdir -p "$CCACHE_DIR"
export CC="ccache clang"
export CXX="ccache clang++"
export HOSTCC="ccache clang"
export HOSTCXX="ccache clang++"

START=$(date +%s)
echo "[4] build start: $(date)"
echo "[4] build.sh: $BUILD_SH"
echo "[4] cwd (ROOT_DIR for _setup_env.sh): $(pwd)"
echo "[4] KERNEL_SRC (private/msm-google): $KERNEL_SRC"
echo "[4] OUT_DIR: $REPO_ROOT/$KERNEL_DIR/$OUT_DIR"

# -c must be a path resolvable from the cwd we just cd'd to.
# Top-level build.config is the symlink the manifest creates.
bash "$BUILD_SH" \
  -c "$REPO_ROOT/$KERNEL_DIR/build.config" \
  -O "$REPO_ROOT/$KERNEL_DIR/$OUT_DIR" \
  -j"$(nproc)" \
  2>&1 | tee "$REPO_ROOT/$KERNEL_DIR/build.log"

END=$(date +%s)
echo "[4] Build duration: $(((END-START)/60))m $(((END-START)%60))s"

BOOT="$REPO_ROOT/$KERNEL_DIR/$OUT_DIR/arch/arm64/boot"
echo "[4] Built images:"
ls -lh "$BOOT" | grep -E "Image|dtb|dtbo" || true

for img in Image.gz-dtb Image.lz4-dtb Image; do
  if [ -f "$BOOT/$img" ]; then
    echo "[4] SUCCESS: $img"
    exit 0
  fi
done
echo "[4] ERROR: no kernel image produced"
exit 1
