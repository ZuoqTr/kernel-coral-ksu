#!/usr/bin/env bash
# Run KSU Next setup.sh for legacy branch + susfs tag.
set -euo pipefail

KSU_TAG="${KSU_TAG:-v3.1.0-legacy-susfs}"
KSU_SETUP_URL="${KSU_SETUP_URL:-https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh}"

cd kernel

echo "[1] Running KSU Next setup for tag: $KSU_TAG"
curl -LSs "$KSU_SETUP_URL" | bash -s "$KSU_TAG"

echo "[1] Verifying KSU integration..."
if [ ! -e drivers/kernelsu ]; then
  echo "[1] ERROR: drivers/kernelsu missing"; exit 1
fi
grep -q "kernelsu/" drivers/Makefile || { echo "[1] drivers/Makefile missing ksu obj"; exit 1; }
grep -q "kernelsu/Kconfig" drivers/Kconfig || { echo "[1] drivers/Kconfig missing ksu source"; exit 1; }

echo "[1] OK: KSU integrated. Files:"
ls drivers/kernelsu/kernel/ | head -10
echo "[1] Makefile tail:"
tail -3 drivers/Makefile
echo "[1] Kconfig tail:"
tail -3 drivers/Kconfig