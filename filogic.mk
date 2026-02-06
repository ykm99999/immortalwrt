define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := Custom-1GB-Edition
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b mediatek,mt7981
  
  # 锁定 128MB 内核分区对齐成果
  KERNEL_SIZE := 134217728
  IMAGE_SIZE := 1073741824
  
  # 强制内核 LZMA 压缩
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)
  
  # 核心驱动包集成
  DEVICE_PACKAGES := \
	kmod-mmc kmod-sdhci-mtk \
	kmod-mt753x \
	kmod-fs-f2fs f2fs-tools f2fsck \
	kmod-usb3 kmod-usb-dwc3-mtk \
	block-mount blkid lsblk parted
  
  # 生成两种格式固件
  IMAGES := sysupgrade.bin sysupgrade.bin.gz
  
  # 拼装逻辑：确保内核 pad 到 128M 偏移处
  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata
  IMAGE/sysupgrade.bin.gz := append-kernel | pad-to 134217728 | append-rootfs | append-metadata | gzip
endef
TARGET_DEVICES += sl3000-emmc
