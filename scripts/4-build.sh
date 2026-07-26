#!/usr/bin/env bash
# Build kernel O=out (matches 3-configure.sh).
# 4.14 msm has a Makefile:619 pattern rule
#   include/config/%.conf: $(KCONFIG_CONFIG) include/config/auto.conf.cmd
# that re-fires silentoldconfig whenever the build itself rewrites
# auto.conf.cmd (which it does constantly during dependency tracking).
# -W include/config/auto.conf tells make to treat auto.conf as just
# modified, breaking the pattern rule's dependency check.
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabihf-
export CC="aarch64-linux-gnu-gcc"

cd kernel

echo "[4] gcc version:"
aarch64-linux-gnu-gcc --version | head -1

START=$(date +%s)
echo "[4] Starting build at $(date)"

# -W include/config/auto.conf: pretend auto.conf was just modified so
# the Makefile:619 pattern rule does not re-evaluate. This is the
# documented workaround for the 4.14 silentoldconfig infinite loop.
#
# HOSTCFLAGS=-fcommon: GCC 10+ defaults to -fno-common; 4.14 dtc
# (dtc-lexer.lex + dtc-parser.tab) has yylloc in two TUs. -fcommon
# merges into single common storage. -Wno-error=unused-function
# silences the Werror upgrade for do_typec_entry in file2alias.c.
make -j"$(nproc)" \
  -W "$OUT_DIR/include/config/auto.conf" \
  O="$OUT_DIR" \
  ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
  HOSTCFLAGS="-fcommon" \
  KBUILD_HOSTCFLAGS="-fcommon" \
  # -Wno-error: 4.14 msm has many known-good patterns that gcc 11/12
  # flags as warnings. Disabling -Werror entirely is simpler than
  # enumerating each warning. 4.14 is end-of-life; warnings are
  # acceptable, hard errors are not.
  KCFLAGS="-Wno-error" \
  Image.gz-dtb 2>&1 | tee ../build.log

END=$(date +%s)
echo "[4] Build duration: $(((END-START)/60))m $(((END-START)%60))s"

BOOT="$OUT_DIR/arch/arm64/boot"
echo "[4] Built images:"
ls -lh "$BOOT" | grep -E "Image|dtb|dtbo" || true

if [ -f "$BOOT/Image.gz-dtb" ]; then
  echo "[4] SUCCESS: Image.gz-dtb present"
elif [ -f "$BOOT/Image.lz4-dtb" ]; then
  echo "[4] SUCCESS: Image.lz4-dtb present (LZ4)"
elif [ -f "$BOOT/Image" ]; then
  echo "[4] SUCCESS: Image present (raw)"
else
  echo "[4] ERROR: No kernel image built"
  exit 1
fi
