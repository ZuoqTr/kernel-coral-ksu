#!/usr/bin/env bash
# Build kernel via AOSP build.sh (pinned in manifest at build/build.sh).
# build.sh reads BUILD_CONFIG = build.config (= build.config.no-cfi
# linkfile, per manifest). It sets up Clang + GCC 4.9 cross-compile via
# the pinned prebuilts and drives make with the right LLVM=1 flags.
# This is the canonical AOSP kernel build flow — sidesteps all the
# source-level hard errors we hit with apt gcc-11 / apt clang-14 /
# Clang-12 tarball orchestration.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
OUT_DIR="${OUT_DIR:-out}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR/private/msm-google"
BUILD_SH="$REPO_ROOT/$KERNEL_DIR/build/build.sh"

if [ ! -x "$BUILD_SH" ]; then
  echo "[4] ERROR: $BUILD_SH not found; run 0-prep-kernel.sh first"
  exit 1
fi

# build.sh's _setup_env.sh does `export ROOT_DIR=$PWD` — overwrites the
# ROOT_DIR that build.sh set from $(dirname $0). So PWD at the moment
# _setup_env.sh runs MUST be the manifest root (the dir holding build.config
# symlink + private/ + prebuilts*/), not the kernel source dir.
# The build.config symlink at kernel/build.config ->
# private/msm-google/build.config.no-cfi is what makes this work; the
# KERNEL_DIR=private/msm-google line inside the .no-cfi file expands relative
# to the cwd's ROOT_DIR.
cd "$REPO_ROOT/$KERNEL_DIR"

# Debug: confirm patches still in place right before build.sh runs
echo "[4-debug] Patches still present?"
for f in fs/exec.c fs/open.c fs/read_write.c fs/stat.c kernel/reboot.c; do
  if grep -q "ksu_handle_" "$KERNEL_SRC/$f"; then
    echo "[4-debug]   $f: OK"
  else
    echo "[4-debug]   $f: MISSING ksu_handle_"
  fi
done
ls -la "$KERNEL_SRC/kernel/reboot.c"

# Do NOT set CC/HOSTCC here. build.sh's CC_ARG logic does
#   CC_ARG="CC=${CC} HOSTCC=${CC}"
# so any CC we export gets mirrored to HOSTCC. kbuild then invokes HOSTCC
# with flags like -E/-r/-W (see Makefile.host:102), which ccache misreads
# as its own options: `ccache: invalid option -- 'E'`. Fix: let build.sh's
# common.clang set CC=clang directly (without ccache wrap). The kernel
# compile is still fast on a fresh checkout because most TUs are cached
# across runs by the GHA actions/cache step on the kernel build dir.
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.cache/ccache}"
mkdir -p "$CCACHE_DIR"
unset CC CXX HOSTCC HOSTCXX

# build.sh does NOT parse -c/-O. It reads these from env (or defaults):
#   BUILD_CONFIG -> defaults to build.config (top-level symlink created by
#                   manifest; expands to private/msm-google/build.config.no-cfi)
#   OUT_DIR      -> COMMON_OUT_DIR; kernel build goes to ${OUT_DIR}/${KERNEL_DIR}
#                   i.e. ${COMMON_OUT_DIR}/private/msm-google
#   DIST_DIR     -> default ${OUT_DIR}/dist
# build.sh passes everything except its own env to the inner `make` calls
# (line 162: MAKE_ARGS=$*), so don't pass unknown flags here. Only the
# make-side options belong on the command line.
COMMON_OUT_DIR="$REPO_ROOT/$KERNEL_DIR/$OUT_DIR"
export OUT_DIR="$COMMON_OUT_DIR"
export BUILD_CONFIG="build.config"
export DIST_DIR="$COMMON_OUT_DIR/dist"

START=$(date +%s)
echo "[4] build start: $(date)"
echo "[4] build.sh: $BUILD_SH"
echo "[4] cwd (ROOT_DIR for _setup_env.sh): $(pwd)"
echo "[4] KERNEL_SRC (private/msm-google): $KERNEL_SRC"
echo "[4] COMMON_OUT_DIR: $COMMON_OUT_DIR"
echo "[4] final kernel build dir: $COMMON_OUT_DIR/private/msm-google"
echo "[4] BUILD_CONFIG: $BUILD_CONFIG (resolves to $KERNEL_SRC/build.config.no-cfi)"

# Debug: dump real file content as make will see it. If patches are there,
# this should show the ksu_handle_ lines.
echo "[4-debug3] Actual file contents (md5 + head of patch region):"
md5sum "$KERNEL_SRC/kernel/reboot.c" || true
echo "[4-debug3] grep -n ksu_handle_sys_reboot:"
grep -n "ksu_handle_sys_reboot" "$KERNEL_SRC/kernel/reboot.c" || echo "  (no match)"
echo "[4-debug3] grep -c ksu_handle_sys_reboot:"
grep -c "ksu_handle_sys_reboot" "$KERNEL_SRC/kernel/reboot.c" || echo "  (no match)"

# build.sh takes no -c/-O flags — only env vars (see build.sh header).
# Pass only make-side options (LLVM/CC/etc handled inside build.sh).
bash "$BUILD_SH" -j"$(nproc)" 2>&1 | tee "$REPO_ROOT/$KERNEL_DIR/build.log"

# Secondary debug: what does the Kbuild shell-eval see? Re-run the exact
# KSU-Next shell expansion OUT-of-the-ksu build, capturing srctree + result.
echo "[4-debug2] Mimicking Kbuild's \$(shell) eval from private/msm-google:"
(
  cd "$KERNEL_SRC"
  SRCTREE="$(pwd)"
  echo "[4-debug2]   PWD=$(pwd)"
  echo "[4-debug2]   SRCTREE=$SRCTREE"
  echo "[4-debug2]   grep on \$SRCTREE/kernel/reboot.c:"
  grep -c "ksu_handle_sys_reboot" "$SRCTREE/kernel/reboot.c" || echo "0 (not found)"
  echo "[4-debug2]   full KSU-Next HAVE_KSU_HOOK eval:"
  grep -q "ksu_handle_sys_reboot" "$SRCTREE/kernel/reboot.c" && echo 0 || echo 1
)
echo "[4-debug2] And from out/private/msm-google (which is where make runs after O=):"
(
  cd "$COMMON_OUT_DIR/private/msm-google"
  SRCTREE="$(pwd)"
  echo "[4-debug2]   PWD=$(pwd)"
  echo "[4-debug2]   SRCTREE=$SRCTREE"
  echo "[4-debug2]   grep on \$SRCTREE/kernel/reboot.c (relative):"
  grep -c "ksu_handle_sys_reboot" "$SRCTREE/kernel/reboot.c" 2>&1 || echo "(missing file)"
)

END=$(date +%s)
echo "[4] Build duration: $(((END-START)/60))m $(((END-START)%60))s"

BOOT="$COMMON_OUT_DIR/private/msm-google/arch/arm64/boot"
echo "[4] Built images:"
ls -lh "$BOOT" | grep -E "Image|dtb|dtbo" || true

for img in Image.gz-dtb Image.lz4-dtb Image; do
  if [ -f "$BOOT/$img" ]; then
    echo "[4] SUCCESS: $img"
    exit 0
  fi
done
echo "[4] ERROR: no kernel image produced"
exit 1
