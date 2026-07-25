#!/usr/bin/env bash
# Non-fatal symbol check using KSU's check_symbol tool.
set -uo pipefail

OUT_DIR="${OUT_DIR:-out}"
cd kernel

VMLINUX=$(find "$OUT_DIR" -name vmlinux -type f 2>/dev/null | head -1)
KSU_KO=$(find "$OUT_DIR" -path "*/kernelsu/kernelsu.ko" 2>/dev/null | head -1)
CHK=$(find "$OUT_DIR" -path "*/kernelsu/check_symbol" -type f 2>/dev/null | head -1)

echo "[5] vmlinux:    $VMLINUX"
echo "[5] kernelsu.ko: $KSU_KO"
echo "[5] check_symbol: $CHK"

if [ -x "$CHK" ] && [ -f "$VMLINUX" ] && [ -f "$KSU_KO" ]; then
  echo "[5] Running check_symbol..."
  "$CHK" "$KSU_KO" "$VMLINUX" || echo "[5] symbol warnings (non-fatal)"
else
  echo "[5] Skipping: missing vmlinux/ko/check_symbol"
fi

# Always show KSU module info
if [ -f "$KSU_KO" ]; then
  echo "[5] KSU module loaded with these symbols (sample):"
  nm "$KSU_KO" 2>/dev/null | grep -E " T (ksu_|susfs_)" | head -10 || true
fi