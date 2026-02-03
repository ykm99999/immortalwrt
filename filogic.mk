DTS_DIR := $(DTS_DIR)/mediatek

define Image/Prepare
	echo -ne '\xde\xad\xc0\xde' > $(KDIR)/ubi_mark
endef

define Build/mt798x-gpt
	cp $@ $@.tmp 2>/dev/null || true
	ptgen -g -o $@.tmp -a 1 -l 1024 \
		-t 0x83 -N ubootenv -r -p 512k@4M \
		-t 0x83 -N factory -r -p 2M@4608k \
		-t 0xef -N fip -r -p 4M@6656k \
		-N recovery -r -p 32M@12M \
		-t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M
	cat $@.tmp >> $@
	rm $@.tmp
endef

define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000
  DEVICE_VARIANT := eMMC
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)
  SUPPORTED_DEVICES := sl,sl3000-emmc
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools kmod-mt7981-firmware kmod-mt7531
  KERNEL := append-kernel | pad-to 64k | append-dtb
  IMAGES := factory.bin sysupgrade.bin
  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt
  IMAGE/sysupgrade.bin := append-rootfs | pad-rootfs | check-size
endef
TARGET_DEVICES += sl3000-emmc
