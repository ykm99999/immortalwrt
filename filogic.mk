DTS_DIR := $(DTS_DIR)/mediatek
define Build/mt798x-gpt
  cp $@ $@.tmp 2>/dev/null || true
  ptgen -g -o $@.tmp -a 1 -l 1024 \
    -t 0x83 -N ubootenv -r -p 512k@4M \
    -t 0xef -N fip -r -p 4M@6656k \
    -t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M
  cat $@.tmp >> $@
  rm $@.tmp
endef
define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := SL3000
  DEVICE_DTS := mt7981b-sl3000-emmc
  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt emmc
endef
TARGET_DEVICES += sl3000-emmc
