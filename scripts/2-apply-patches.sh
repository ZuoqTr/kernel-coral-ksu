#!/usr/bin/env bash
# Apply KernelSU Next manual hooks + simonpunk susfs4ksu kernel-4.14 patch.
#
# Order:
#  1. Setup KSU (handled by 1-setup-ksu.sh — creates drivers/kernelsu symlink)
#  2. Apply 5 manual-hooks patches (ksu_handle_* externs + calls in syscall sites)
#  3. Apply simonpunk susfs4ksu 50_add_susfs_in_kernel-4.14.patch
#     (configures CONFIG_KSU_SUSFS=y hooks: fs/{namespace,dcache,namei,readdir,
#     proc_namespace,notify/fdinfo,proc/cmdline,proc/task_mmu}, include/linux/
#     {mount.h,stat.h,sched.h}, kernel/{kallsyms,sys}.c)
#  4. Copy susfs source files (fs/susfs.c, fs/sus_su.c, include/linux/susfs*.h)
#  5. Add susfs.o + sus_su.o to fs/Makefile (if not already patched in)
#
# Source: simonpunk/susfs4ksu kernel-4.14 branch (v1.5.5). NOT ShirkNeko
# (ShirkNeko's patches are authored for tiann/KernelSU; they don't link
# against KSU Next's hook surface). NOT upstream KSU Next tag (KSU Next
# v3.1.0-legacy-susfs Kbuild expects external fs/susfs.c + include/linux/
# susfs.h — does NOT bundle them).
#
# KSU Next: sidex15/KernelSU-Next legacy-susfs-v2 branch (fork adapted
# for legacy-susfs branches). KSU_TAG env var defaults to legacy-susfs-v2.
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_SRC="$REPO_ROOT/$KERNEL_DIR"
HOOK_DIR="$REPO_ROOT/patches/ksu-manual-hooks"
SUSFS_DIR="$REPO_ROOT/patches/susfs-kernel-4.14"

cd "$KERNEL_SRC"

# --- step 1: setup KSU (handled by 1-setup-ksu.sh before this script) ---
echo "[2a] Verifying drivers/kernelsu symlink exists..."
test -e drivers/kernelsu || { echo "drivers/kernelsu missing — did 1-setup-ksu.sh run?"; exit 1; }
grep -q "kernelsu/" drivers/Makefile
grep -q "kernelsu/Kconfig" drivers/Kconfig

# --- step 2: manual-hooks patches ---
echo "[2b] Applying 5 manual-hooks patches..."
for p in "$HOOK_DIR"/*.patch; do
  echo "[2b]   $p"
  git apply --verbose "$p" || {
    echo "[2b] FAILED: $p"
    git apply --verbose --ignore-whitespace "$p" || exit 1
  }
done

for f in fs/exec.c fs/open.c fs/read_write.c fs/stat.c kernel/reboot.c; do
  if ! grep -q "ksu_handle_" "$f"; then
    echo "[2b] MISSING hooks in $f"; exit 1
  fi
done
echo "[2b] OK: all 5 manual hooks applied"

# --- step 3: simonpunk susfs4ksu kernel-4.14 patch ---
echo "[2c] Applying simonpunk susfs4ksu kernel-4.14 patch..."
SUSFS_PATCH="$SUSFS_DIR/0001-simonpunk-susfs4ksu.patch"
test -f "$SUSFS_PATCH" || { echo "[2c] MISSING $SUSFS_PATCH"; exit 1; }
git apply --verbose --reject --whitespace=nowarn "$SUSFS_PATCH" || {
  echo "[2c] FAILED: patch apply"
  exit 1
}

# Count remaining rejects — must be 0 (msm-4.14 pre-4.18 IDA API matches
# simonpunk kernel-4.14 branch).
REJ_COUNT=$(find . -name '*.rej' 2>/dev/null | wc -l | tr -d ' ')
if [ "$REJ_COUNT" -gt 0 ]; then
  echo "[2c] WARNING: $REJ_COUNT .rej files remaining:"
  find . -name '*.rej' -exec ls -la {} \;
  echo "[2c] FAILED: must fix rejects manually before continuing"
  exit 1
fi
echo "[2c] OK: susfs4ksu kernel patch applied clean"

# --- step 4: copy susfs source files ---
echo "[2d] Copying susfs source files..."
cp "$SUSFS_DIR/fs/susfs.c" fs/susfs.c
cp "$SUSFS_DIR/fs/sus_su.c" fs/sus_su.c
cp "$SUSFS_DIR/include/linux/susfs.h" include/linux/susfs.h
cp "$SUSFS_DIR/include/linux/susfs_def.h" include/linux/susfs_def.h
echo "[2d] OK: susfs sources copied"

# --- step 5: ensure fs/Makefile has susfs.o + sus_su.o ---
echo "[2e] Ensuring fs/Makefile has susfs objects..."
if ! grep -q "susfs.o" fs/Makefile; then
  python3 -c "
p='fs/Makefile'
s=open(p).read()
add='obj-\$(CONFIG_KSU_SUSFS) += susfs.o\nobj-\$(CONFIG_KSU_SUSFS_SUS_SU) += sus_su.o\n\n'
import re
s=re.sub(r'(obj-y\s*:=[^\n]*\n)', r'\1\n'+add, s, count=1)
open(p,'w').write(s)
"
  echo "[2e] Added susfs.o + sus_su.o to fs/Makefile"
else
  echo "[2e] fs/Makefile already has susfs objects"
fi

# --- step 6: sanity ---
echo "[2f] Verifying..."
grep -q "config KSU_SUSFS" drivers/kernelsu/Kconfig || {
  echo "[2f] MISSING KSU_SUSFS in drivers/kernelsu/Kconfig"; exit 1; }
test -f fs/susfs.c || { echo "[2f] MISSING fs/susfs.c"; exit 1; }
test -f include/linux/susfs.h || { echo "[2f] MISSING include/linux/susfs.h"; exit 1; }
grep -q "DEFAULT_SUS_MNT_ID" include/linux/susfs.h || { echo "[2f] susfs.h corrupt"; exit 1; }
grep -q "alloc_vfsmnt" fs/namespace.c || { echo "[2f] namespace.c patch failed"; exit 1; }

echo "[2] All patches applied successfully (KSU + simonpunk susfs)"