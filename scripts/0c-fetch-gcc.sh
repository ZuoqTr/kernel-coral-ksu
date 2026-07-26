#!/usr/bin/env bash
# Fetch GCC 4.9 cross-compilers for the kernel build.
#
# Why KudProject forks (NOT AOSP prebuilts): the upstream AOSP
# prebuilts/gcc/linux-x86/{aarch64,arm}/...-4.9 tree at android-10.0.0_r47
# is **binutils-only** (verified: tarball contains ar/as/ld/nm/strip/objcopy
# but NO gcc compiler binary). The kernel needs gcc to compile C/asm
# TUs with CONFIG_LTO_NONE/clang integrated assembler. KudProject forks
# (KudProject/aarch64-linux-android-4.9.git, KudProject/arm-linux-androideabi-4.9.git)
# add the gcc compiler binary on top of AOSP's binutils tree.
#
# Used as CROSS_COMPILE (aarch64) and CROSS_COMPILE_ARM32 (arm).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREBUILTS_DIR="$REPO_ROOT/kernel-build/prebuilts"

fetch_prebuilt() {
  local name="$1"
  local url="$2"
  local prefix="$3"
  local dest="$PREBUILTS_DIR/$name"
  if [ -x "$dest/bin/${prefix}gcc" ]; then
    echo "[0c] $name already extracted at $dest/bin/${prefix}gcc"
    return
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  echo "[0c] Fetching $name from $url"
  curl -LSs -o "$dest.tar.gz" "$url" || { echo "[0c] FAILED: $url"; exit 1; }
  tar -xzf "$dest.tar.gz" -C "$dest" --strip-components=1
  rm -f "$dest.tar.gz"
  if [ ! -x "$dest/bin/${prefix}gcc" ]; then
    echo "[0c] ERROR: ${prefix}gcc missing after extract"
    ls -la "$dest/bin/" 2>&1 | head
    exit 1
  fi
}

mkdir -p "$PREBUILTS_DIR"

# aarch64-linux-android-4.9 (KudProject fork with gcc compiler)
fetch_prebuilt "aarch64-linux-android-4.9" \
  "https://codeload.github.com/KudProject/aarch64-linux-android-4.9/tar.gz/refs/heads/master" \
  "aarch64-linux-android-"

# arm-linux-androideabi-4.9 (KudProject fork with gcc compiler)
fetch_prebuilt "arm-linux-androideabi-4.9" \
  "https://codeload.github.com/KudProject/arm-linux-androideabi-4.9/tar.gz/refs/heads/master" \
  "arm-linux-androideabi-"

echo "[0c] Prebuilts ready:"
"$PREBUILTS_DIR/aarch64-linux-android-4.9/bin/aarch64-linux-android-gcc" --version | head -1
"$PREBUILTS_DIR/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-gcc" --version | head -1