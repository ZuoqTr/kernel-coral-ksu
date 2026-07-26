#!/usr/bin/env bash
# Fetch AOSP GCC 4.9 prebuilts (aarch64 + arm) at android10-qpr3 release.
# 4.14 msm's arch/arm64/Makefile:83 requires CROSS_COMPILE_ARM32 for 32-bit
# compat vDSO. apt arm-linux-androideabi on Ubuntu 22.04 is too old (no
# LSE atomics, broken .inst handling). Use AOSP prebuilts.
#
# Pinned in kernel/manifest at android-msm-coral-4.14-android10-qpr3;
# we fetch the same revisions directly via codeload.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREBUILTS_DIR="$REPO_ROOT/kernel-build/prebuilts"

# android10-qpr3 branch tag for prebuilts (latest r47 in 10.0.0 series)
GCC_AARCH64_TAG="android-10.0.0_r47"
GCC_ARM_TAG="android-10.0.0_r47"

# AOSP prebuilt GCC projects (googlesource). Use codeload for direct tar.
fetch_prebuilt() {
  local name="$1"
  local url="$2"
  local prefix="$3"  # e.g. aarch64-linux-android-
  local dest="$PREBUILTS_DIR/$name"
  if [ -x "$dest/bin/${prefix}gcc" ]; then
    echo "[0c] $name already extracted"
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

# aarch64-linux-android-4.9 (for CROSS_COMPILE)
fetch_prebuilt "aarch64-linux-android-4.9" \
  "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/${GCC_AARCH64_TAG}.tar.gz" \
  "aarch64-linux-android-"

# arm-linux-androideabi-4.9 (for CROSS_COMPILE_ARM32)
fetch_prebuilt "arm-linux-androideabi-4.9" \
  "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/${GCC_ARM_TAG}.tar.gz" \
  "arm-linux-androideabi-"

echo "[0c] Prebuilts:"
ls "$PREBUILTS_DIR/aarch64-linux-android-4.9/bin/" | head -3
ls "$PREBUILTS_DIR/arm-linux-androideabi-4.9/bin/" | head -3