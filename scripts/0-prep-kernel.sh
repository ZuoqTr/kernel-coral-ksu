#!/usr/bin/env bash
# Manifest-driven kernel checkout. The manifest (kernel/manifest @
# android-msm-coral-4.14-android10-qpr3) pins:
#   - kernel/msm (private/msm-google) at the coral branch
#   - kernel/msm-extra (audio techpack)
#   - kernel/msm-modules/{data-kernel, qca-wifi, touch}
#   - prebuilts/gcc/linux-x86/{aarch64,arm}/...-4.9 at pie-release
#   - prebuilts-master/clang/host/linux-x86 (NOT prebuilts/clang)
#   - build/ (the AOSP build.sh wrapper)
# `repo` checks these out into KERNEL_DIR. After sync, the actual kernel
# source is at KERNEL_DIR/private/msm-google.
set -uo pipefail

KERNEL_SOURCE_URL="${KERNEL_SOURCE_URL:-https://android.googlesource.com/kernel/manifest}"
KERNEL_SOURCE_BRANCH="${KERNEL_SOURCE_BRANCH:-android-msm-coral-4.14-android10-qpr3}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"

# Install repo launcher. apt's repo (2.16 on ubuntu-22.04) lacks
# --groups. The googleapis launcher auto-fetches current repo main
# on first invocation (≥2.40 has --groups). Always use launcher.
# Pin REPO_REV=main so the launcher fetches current, not the cached
# "stable" branch (which still points at an old snapshot).
mkdir -p "$HOME/.bin"
curl -LSso "$HOME/.bin/repo" https://storage.googleapis.com/git-repo-downloads/repo
chmod +x "$HOME/.bin/repo"
export PATH="$HOME/.bin:$PATH"
export REPO_REV=main

rm -rf "$KERNEL_DIR"
mkdir -p "$KERNEL_DIR"
cd "$KERNEL_DIR"
KERNEL_DIR="$(pwd)"  # absolute path for post-sync dump

# `--groups all` is required: the coral manifest tags the Clang
# prebuilt with groups="partner"; default repo sync skips partner
# projects which silently leaves prebuilts-master/clang empty.
# Use --no-repo-verify because googleapis launcher differs from the
# kernel/manifest's pinned repo hash.
repo init -u "$KERNEL_SOURCE_URL" -b "$KERNEL_SOURCE_BRANCH" --depth=1 --no-repo-verify
repo sync -c -j"$(nproc)" --no-tags --groups all

# Verify kernel source actually checked out
echo "[0] === POST-SYNC DUMP ==="
echo "[0] kernel/ top-level:"
ls -la "$KERNEL_DIR" 2>&1 | head -30 || true
echo "[0] kernel/build/:"
ls "$KERNEL_DIR/build/" 2>&1 | head -10 || true
echo "[0] kernel/prebuilts/:"
ls "$KERNEL_DIR/prebuilts/" 2>&1 | head -10 || true
echo "[0] kernel/prebuilts-master/clang/host/linux-x86/:"
ls "$KERNEL_DIR/prebuilts-master/clang/host/linux-x86/" 2>&1 | head -5 || true
echo "[0] kernel/private/msm-google/:"
ls "$KERNEL_DIR/private/msm-google/" 2>&1 | head -10 || true
echo "[0] === END DUMP ==="

KERNEL_SRC="$KERNEL_DIR/private/msm-google"
if [ ! -d "$KERNEL_SRC/arch/arm64/configs" ]; then
  echo "[0] ERROR: $KERNEL_SRC missing or incomplete"
  exit 1
fi
echo "[0] Available defconfigs (coral/flame/floral):"
ls "$KERNEL_SRC/arch/arm64/configs/" 2>&1 | grep -E "defconfig$" || true

# Verify build.sh present (pinned by manifest)
if [ ! -x "build/build.sh" ]; then
  echo "[0] ERROR: build/build.sh missing"
  exit 1
fi
echo "[0] build.sh present at build/build.sh"

# Verify prebuilts (note: clang is in prebuilts-master/, NOT prebuilts/)
echo "[0] Clang prebuilt:"
ls prebuilts-master/clang/host/linux-x86/clang-*/bin/clang 2>/dev/null | head -1 || true
echo "[0] GCC 4.9 prebuilt (64-bit):"
ls prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/ 2>/dev/null | head -3 || true
echo "[0] GCC 4.9 prebuilt (32-bit):"
ls prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/ 2>/dev/null | head -3 || true

echo "[0] prep complete: KERNEL_SRC=$KERNEL_SRC"