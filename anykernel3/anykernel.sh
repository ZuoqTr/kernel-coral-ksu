# AnyKernel3 - Pixel 4 (coral) - KernelSU Next + susfs
umask 0

kernel.string="KernelSU Next + susfs (coral, AP2A.240905.003)"
device.name1=coral
device.name2=flame
device.name3=pixel4

# A/B slot detection
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
[ -z "$SLOT" ] && SLOT=$(cat /proc/cmdline 2>/dev/null | grep -oE 'androidboot\.slot_suffix=[^ ]+' | cut -d= -f2)
[ -z "$SLOT" ] && SLOT="_a"

# Boot block candidates for coral (try in order)
block=/dev/block/by-name/boot$SLOT
[ ! -b "$block" ] && block=/dev/block/bootdevice/by-name/boot$SLOT
[ ! -b "$block" ] && block=/dev/block/platform/soc/1d84000.ufshc/by-name/boot$SLOT

do.devicecheck() {
  for d in $device.name1 $device.name2 $device.name3; do
    if grep -qE "^ro\.product\.device=$d|^ro\.build\.product=$d" /system/build.prop 2>/dev/null; then
      return 0
    fi
  done
  ui_print "(!) Device not coral/flame/pixel4. Aborting."
  return 1
}

do.modules() {
  mount -o rw,remount /system 2>/dev/null
  if [ -d /system/lib/modules ]; then
    cp -f *.ko /system/lib/modules/ 2>/dev/null
    chmod 644 /system/lib/modules/*.ko 2>/dev/null
  fi
  mount -o ro,remount /system 2>/dev/null
}

do.cleanup() {
  rm -rf /tmp/anykernel
  mkdir -p /tmp/anykernel
  cp -r ./* /tmp/anykernel/ 2>/dev/null
  cd /tmp/anykernel
}

ui_print " "
ui_print "- KernelSU Next + susfs for coral -"
ui_print "- Slot: $SLOT -"
ui_print "- Block: $block -"
ui_print " "

unzip -o "$3"
do.cleanup
flush_out
dump_boot
write_boot