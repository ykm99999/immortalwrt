define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := Custom-1GB-Edition
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b
  
  # 【单位数字化】64M -> 65536k | 1024M -> 1048576k
  KERNEL_SIZE := 65536k
  IMAGE_SIZE := 1048576k
  
  DEVICE_PACKAGES := \
	kmod-mmc kmod-sdhci-mtk \
	kmod-fs-f2fs f2fs-tools f2fsck \
	kmod-usb3 kmod-usb-dwc3-mtk \
	block-mount blkid lsblk parted
  
  IMAGES := factory.bin sysupgrade.bin
  IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs | check-size | mtk-sdcard
  IMAGE/sysupgrade.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs | check-size | mtk-sdcard
endef
TARGET_DEVICES += sl3000-emmc
