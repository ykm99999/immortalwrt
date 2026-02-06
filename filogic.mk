define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := Custom-128GB-Edition
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b mediatek,mt7981
  
  # 🎯 物理对齐延续：内核 128MB，总镜像 1GB
  KERNEL_SIZE := 134217728
  IMAGE_SIZE := 1073741824
  
  # 🎯 修复 Error 2 的核心宏
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)
  
  # 📦 预装扩容工具：发挥 128GB 和 1GB RAM 威力
  DEVICE_PACKAGES := \
	kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \
	kmod-usb3 kmod-usb-dwc3-mtk block-mount blkid lsblk parted \
	kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin sysupgrade.bin.gz
  
  # 🎯 延续修复：使用 pad-to 强制物理对齐
  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata
  IMAGE/sysupgrade.bin.gz := append-kernel | pad-to 134217728 | append-rootfs | append-metadata | gzip

  # 🛡️ 强制关掉导致报错的救援包
  KERNEL_INITRAMFS := 
endef
TARGET_DEVICES += sl3000-emmc
