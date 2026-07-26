#!/usr/bin/env bash
# Clone coral kernel source tree at the exact branch and patch the
# 4.14 silentoldconfig-loop pattern rule in Makefile.
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

# Patch Makefile:619 silentoldconfig pattern rule with a stamp-file
# guard to break the 4.14 msm infinite loop.
#
# Original (lines 619-620):
#   include/config/%.conf: $(KCONFIG_CONFIG) include/config/auto.conf.cmd
#           $(Q)$(MAKE) -f $(srctree)/Makefile silentoldconfig
#
# The pattern rule re-fires every time the build rewrites
# include/config/auto.conf.cmd (which kbuild does constantly during
# dependency tracking) because the sub-make's regeneration of
# auto.conf.cmd makes it newer than auto.conf, retriggering the
# pattern rule.
#
# Replacement: gate the recipe on a stamp file. After the first
# silentoldconfig invocation (from configure.sh), the stamp exists;
# the recipe check prevents re-running. The pattern rule's prereqs
# remain auto.conf.cmd, so make still sees the dep — but the recipe
# short-circuits when the stamp is current.
echo "[0] Patching Makefile:619 pattern-rule loop guard"
python3 - <<'PYEOF'
import pathlib
p = pathlib.Path("Makefile")
src = p.read_text()
old = ("include/config/%.conf: $(KCONFIG_CONFIG) include/config/auto.conf.cmd\n"
       "\t$(Q)$(MAKE) -f $(srctree)/Makefile silentoldconfig\n")
new = ("include/config/%.conf: $(KCONFIG_CONFIG) include/config/auto.conf.cmd\n"
       "\t@if [ ! -f $@ ]; then \\\n"
       "\t\t$(Q)$(MAKE) -f $(srctree)/Makefile silentoldconfig; \\\n"
       "\tfi\n")
if old not in src:
    print("[0] WARN: Makefile pattern not found verbatim; skipping patch", flush=True)
else:
    src = src.replace(old, new, 1)
    p.write_text(src)
    print("[0] Makefile pattern patched", flush=True)
PYEOF

grep -n "conf.stamp" Makefile || echo "[0] patch did NOT apply"

# Replace scripts/gcc-wrapper.py with a Python 3 port.
# msm-4.14 ships the wrapper as Python 2 syntax (print >> sys.stderr,
# bytes iteration from proc.stderr). Ubuntu 22.04 ships Python 3.10+
# which breaks both. Whole-file replacement is cleaner than sed-patch
# since the original has 3 incompatible constructs.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f scripts/gcc-wrapper.py ]; then
  cp "../scripts/gcc-wrapper-py3.py" scripts/gcc-wrapper.py
  chmod +x scripts/gcc-wrapper.py
  echo "[0] gcc-wrapper.py replaced with py3 port"
else
  echo "[0] gcc-wrapper.py not present (legacy kbuild path), skip"
fi

# Disable kbuild's -Werror injection. 4.14 msm hard-codes
# KBUILD_CFLAGS += -Werror in scripts/Makefile.build. gcc 11/12
# produce many false-positive warnings on 4.14 arm64 code; treating
# as errors blocks every build. CONFIG_WERROR is not in 4.14
# Kconfig, so the only way out is to patch the Makefile.
# Use a benign -Wno-error flag that survives Makefile.build's
# KBUILD_CFLAGS composition.
sed -i 's|-Werror|-Wno-error|g' scripts/Makefile.build
echo "[0] -Werror -> -Wno-error in scripts/Makefile.build"
grep -c "\-Wno-error" scripts/Makefile.build
