# kernel-coral-ksu

AnyKernel3-flashable kernel for **Pixel 4 (coral)** running **Android 14 (AP2A.240905.003)**, integrating **KernelSU Next (legacy branch, `v3.1.0-legacy-susfs`)** with the **susfs** feature set, built via GitHub Actions.

## Stack

- **Kernel source:** `https://android.googlesource.com/kernel/msm -b android-msm-coral-4.14-android10-qpr3`
- **Defconfig base:** `arch/arm64/configs/floral_defconfig` (coral reuses floral config on sm8150)
- **KSU:** `KernelSU-Next/KernelSU-Next` legacy branch, tag `v3.1.0-legacy-susfs` (built-in susfs hooks, manual function-call hooks for non-kprobe kernels)
- **Toolchain:** GCC AArch64 cross-compiler (`gcc-aarch64-linux-gnu` from apt)
- **Build host:** GitHub Actions `ubuntu-22.04`
- **Output:** `AnyKernel3-coral-<date>.zip` (TWRP/KSU-recovery sideload)

## How to build

1. Push this repo to your GitHub account (private or public).
2. Go to **Actions → Build Coral KSU Kernel → Run workflow**.
3. Wait ~30-60 min for first build (ccache speeds up subsequent builds to ~10-15 min).
4. Download the `AnyKernel3-coral-N.zip` artifact from the completed run.

### CLI trigger

```bash
gh workflow run build.yml
gh run watch
gh run download <run-id> --name "AnyKernel3-coral-N" --dir ./
```

## How to flash

### Via TWRP

```bash
adb reboot recovery
# TWRP: Advanced → ADB Sideload → Swipe to Start
adb sideload AnyKernel3-coral-YYYYMMDD.zip
```

### Via fastboot (extract Image first)

```bash
unzip AnyKernel3-coral-YYYYMMDD.zip Image.gz-dtb
adb reboot bootloader
fastboot flash boot Image.gz-dtb
fastboot reboot
```

## Post-flash

1. Install the **KSU Next manager APK** from
   `https://github.com/KernelSU-Next/KernelSU-Next/releases`.
2. Push the `ksu_susfs` userspace binary (arm64) to `/data/adb/ksu/bin/ksu_susfs`.

### Verify

```bash
adb shell dmesg | grep -iE 'kernelsu|susfs'
adb shell uname -r                       # should end in -KSU-SUSFS-coral
adb shell su -c "ksu_susfs show_version"
adb shell su -c "ksu_susfs show_enabled_features"
```

## Rollback

```bash
adb reboot bootloader
fastboot flash boot boot-stock.img
fastboot reboot
```

## Repo layout

```
.github/workflows/build.yml     # GHA workflow
scripts/                         # 0-prep, 1-ksu, 2-patches, 3-configure, 4-build, 5-verify, 6-ak3
patches/ksu-manual-hooks/        # 5 .patch files for 4.14 manual hooks
kernel-defconfig-fragments/      # ksu-susfs.config fragment
anykernel3/                      # AK3 template (anykernel.sh, META-INF, update-binary)
```

## Pitfalls

- **`floral_defconfig`, not `coral_defconfig`.** Coral on sm8150 reuses the floral defconfig.
- **Output may be `Image.lz4-dtb`** (coral uses LZ4 kernel compression).
- **AVB verity** must be disabled or the device will reject the new boot. The Pixel 4 needs `adb disable-verity` if the kernel is signed with a different key.
- **`EXTRAVERSION` is appended in GHA step** so `uname -r` shows the build tag.
- **Kprobes are disabled** (`CONFIG_KSU_KPROBES_HOOK=n`); only manual hooks apply. 4.14 has unreliable kprobe support.
