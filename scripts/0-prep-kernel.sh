#!/usr/bin/env bash
# Clone coral kernel source tree at the exact branch.
set -euo pipefail

KERNEL_SOURCE_URL="${KERNEL_SOURCE_URL:-https://android.googlesource.com/kernel/msm}"
KERNEL_SOURCE_BRANCH="${KERNEL_SOURCE_BRANCH:-android-msm-coral-4.14-android10-qpr3}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"

rm -rf "$KERNEL_DIR"
git clone --depth=1 --branch "$KERNEL_SOURCE_BRANCH" "$KERNEL_SOURCE_URL" "$KERNEL_DIR"
cd "$KERNEL_DIR"
git log --oneline -1
echo "[0] Available defconfigs:"
ls arch/arm64/configs/ | grep -E 'defconfig$' || true
echo "[0] Available vendor defconfigs:"
ls arch/arm64/configs/vendor/ 2>/dev/null | grep -E 'defconfig$' || true