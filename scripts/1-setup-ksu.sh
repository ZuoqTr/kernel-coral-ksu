#!/usr/bin/env bash
# Run KSU Next setup.sh for legacy branch.
# Kprobes mode: KSU Next uses CONFIG_KPROBES=y for hook attachment.
# No manual-hooks kernel patches needed — the kprobes hook mode does
# the runtime relocation at module-load time.
set -euo pipefail

KSU_TAG="${KSU_TAG:-v3.1.0-legacy}"
KSU_SETUP_URL="${KSU_SETUP_URL:-https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh}"

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"

cd "$KERNEL_SRC"

echo "[1] Running KSU Next setup for tag: $KSU_TAG"
curl -LSs "$KSU_SETUP_URL" | bash -s "$KSU_TAG"

echo "[1] Verifying KSU integration..."
if [ ! -e drivers/kernelsu ]; then
  echo "[1] ERROR: drivers/kernelsu missing"; exit 1
fi
grep -q "kernelsu/" drivers/Makefile || { echo "[1] drivers/Makefile missing ksu obj"; exit 1; }
grep -q "kernelsu/Kconfig" drivers/Kconfig || { echo "[1] drivers/Kconfig missing ksu source"; exit 1; }

echo "[1] OK: KSU integrated (kprobes mode)"
ls drivers/kernelsu/ | head -15

# Patch scripts/dtc/dtc-parser.y to make yylloc extern. Clang 12+ default
# -fno-common causes link failure: yylloc defined in both dtc-parser.tab.o
# and dtc-lexer.lex.o. bison generates 'int yylloc' as a common tentative
# def in dtc-parser.tab.c; same in dtc-lexer.lex.c. With -fno-common,
# both become strong defs and the linker rejects the duplicate.
# Fix: in dtc-parser.y, add '%code provides' block declaring 'int yylloc'
# (in parser) and add 'extern int yylloc' at top of dtc-lexer.l so lexer
# references the parser's instance.
DTC_PARSER="scripts/dtc/dtc-parser.y"
DTC_LEXER="scripts/dtc/dtc-lexer.l"
if [ -f "$DTC_LEXER" ] && ! grep -q "^extern int yylloc" "$DTC_LEXER"; then
  sed -i '1i extern int yylloc;' "$DTC_LEXER"
  echo "[1] Patched dtc-lexer.l: extern int yylloc"
fi
if [ -f "$DTC_PARSER" ] && ! grep -q "extern int yylloc\|provide.*yylloc" "$DTC_PARSER"; then
  # Add YYLLOC definition in parser prologue (becomes strong def in .tab.c)
  sed -i '1i int yylloc;' "$DTC_PARSER"
  echo "[1] Patched dtc-parser.y: int yylloc (strong def)"
fi