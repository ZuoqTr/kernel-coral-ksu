#!/usr/bin/env bash
# Direct git clone of kernel/msm — no AOSP manifest, no build.sh.
# Sidesteps silentoldconfig + check_defconfig issues from manifest+build.sh
# flow. Source layout: $KERNEL_DIR/ == kernel source root.
set -euo pipefail

KERNEL_SOURCE_URL="${KERNEL_SOURCE_URL:-https://android.googlesource.com/kernel/msm}"
KERNEL_SOURCE_BRANCH="${KERNEL_SOURCE_BRANCH:-android-msm-coral-4.14-android10-qpr3}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$REPO_ROOT/$KERNEL_DIR"
git clone --depth=1 --branch "$KERNEL_SOURCE_BRANCH" "$KERNEL_SOURCE_URL" "$REPO_ROOT/$KERNEL_DIR"

cd "$REPO_ROOT/$KERNEL_DIR"
KERNEL_SHA=$(git rev-parse --short HEAD)
echo "[0] Kernel cloned: $KERNEL_SOURCE_BRANCH @ $KERNEL_SHA"

ls "$REPO_ROOT/$KERNEL_DIR/arch/arm64/configs/" | grep -E "coral|floral" || {
  echo "[0] ERROR: coral/floral defconfig missing"; exit 1; }
echo "[0] KERNEL_SRC=$REPO_ROOT/$KERNEL_DIR"