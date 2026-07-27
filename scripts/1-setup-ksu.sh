#!/usr/bin/env bash
# Setup KSU Next from sidex15 fork (legacy-susfs-v2 branch).
# Bypasses sidex15's setup.sh (which uses git pull + checkout that can lose
# local refs). Instead: shallow clone with --branch flag, copy kernel/ into
# drivers/kernelsu, integrate Makefile/Kconfig entries.
#
# Why sidex15 fork: upstream KSU Next `next` branch / `v3.1.0-legacy-susfs` tag
# has its own in-module susfs surface (kernel_umount.c, su_mount_ns.c) that
# doesn't pair cleanly with the simonpunk susfs4ksu kernel-4.14 patch series.
# sidex15 maintains `legacy-susfs-v2` which is the matching branch for simonpunk.
#
# 4.14 msm lacks HAVE_SYSCALL_TRACEPOINTS so kprobes mode is unavailable;
# we apply manual hooks via patches/ksu-manual-hooks/ in 2-apply-patches.sh.
set -euo pipefail

KSU_OWNER="${KSU_OWNER:-sidex15}"
KSU_REPO="${KSU_REPO:-KernelSU-Next}"
KSU_TAG="${KSU_TAG:-legacy-susfs-v2}"

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
KSU_TMP="/tmp/${KSU_REPO}-${KSU_TAG}"
KSU_URL="https://github.com/${KSU_OWNER}/${KSU_REPO}.git"

cd "$KERNEL_SRC"

echo "[1] Cloning ${KSU_URL} @ ${KSU_TAG}..."
rm -rf "$KSU_TMP"
git clone --depth=1 --branch "$KSU_TAG" "$KSU_URL" "$KSU_TMP" 2>&1 | tail -3

# Clean stale drivers/kernelsu if present (from prior runs).
rm -rf drivers/kernelsu

# Copy KSU Next kernel/ into drivers/kernelsu. sidex15 layout has subdirs
# (core/, hook/, etc.) — copy wholesale.
echo "[1] Copying KSU Next kernel/ → drivers/kernelsu/..."
mkdir -p drivers/kernelsu
cp -R "$KSU_TMP/kernel/." drivers/kernelsu/

# Drop setup.sh + build-all.sh + .vscode (out-of-tree build scripts).
rm -f drivers/kernelsu/setup.sh drivers/kernelsu/build-all.sh
rm -rf drivers/kernelsu/.vscode

# Integrate into drivers/Makefile + drivers/Kconfig if not already.
echo "[1] Integrating into drivers/Makefile + drivers/Kconfig..."
if ! grep -q "kernelsu/" drivers/Makefile; then
  printf '\nobj-$(CONFIG_KSU)\t\t+= kernelsu/\n' >> drivers/Makefile
  echo "[1] Added KSU to drivers/Makefile"
fi
if ! grep -q "drivers/kernelsu/Kconfig" drivers/Kconfig; then
  python3 -c "
p='drivers/Kconfig'
s=open(p).read()
s=s.replace('source \"drivers/esoc/Kconfig\"\n\nendmenu\n',
            'source \"drivers/esoc/Kconfig\"\n\nsource \"drivers/kernelsu/Kconfig\"\n\nendmenu\n', 1)
open(p,'w').write(s)
"
  echo "[1] Added KSU source to drivers/Kconfig"
fi

echo "[1] Verifying..."
test -e drivers/kernelsu/Kconfig || { echo "[1] ERROR: Kconfig missing"; exit 1; }
test -e drivers/kernelsu/Makefile || { echo "[1] ERROR: Makefile missing"; exit 1; }
test -e drivers/kernelsu/Kbuild || { echo "[1] ERROR: Kbuild missing"; exit 1; }
grep -q "config KSU_SUSFS" drivers/kernelsu/Kconfig || { echo "[1] KSU_SUSFS missing in Kconfig"; exit 1; }

echo "[1] OK: KSU integrated (${KSU_OWNER}/${KSU_TAG})"
echo "[1] drivers/kernelsu contents:"
ls drivers/kernelsu/ | head -15