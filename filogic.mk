DTS_DIR := $(DTS_DIR)/mediatek

define Image/Prepare
	echo -ne '\xde\xad\xc0\xde' > $(KDIR)/ubi_mark
endef

define Build/mt7981-bl2
	cat $(STAGING_DIR_IMAGE)/mt7981-$(1)-bl2.img >> $@
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
  DEVICE_MODEL := SL3000
  DEVICE_VARIANT := eMMC
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)
  SUPPORTED_DEVICES := sl,sl3000-emmc
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools
  IMAGES := sysupgrade.itb factory.bin
  IMAGE/sysupgrade.itb := append-kernel | append-dtb | append-metadata
  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt emmc
endef
TARGET_DEVICES += sl3000-emmc
