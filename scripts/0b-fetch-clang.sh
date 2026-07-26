#!/usr/bin/env bash
# Fetch Clang 12 r416183b from LineageOS prebuilts.
# 4.14 msm written for Clang 12; Clang 14+ rejects __builtin_constant_p
# stricter and breaks FORTIFY in arch/arm64/. r416183b = last AOSP Clang
# that compiles 4.14 msm cleanly.
set -euo pipefail

CLANG_URL="${CLANG_URL:-https://codeload.github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b/tar.gz/refs/heads/lineage-20.0}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLANG_DIR="$REPO_ROOT/kernel-build/clang-r416183b"

mkdir -p "$CLANG_DIR"
if [ ! -x "$CLANG_DIR/bin/clang" ]; then
  echo "[0b] Fetching Clang 12 r416183b..."
  cd "$CLANG_DIR"
  curl -LSs -o clang.tar.gz "$CLANG_URL"
  tar -xzf clang.tar.gz --strip-components=1
  rm -f clang.tar.gz
else
  echo "[0b] Clang already extracted at $CLANG_DIR/bin/clang"
fi

CLANG_VER=$("$CLANG_DIR/bin/clang" --version | head -1)
echo "[0b] Clang: $CLANG_VER"
"$CLANG_DIR/bin/clang" --target=aarch64-linux-gnu --print-target-triple 2>/dev/null || true