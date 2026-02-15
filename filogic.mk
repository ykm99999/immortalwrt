define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000 (eMMC)
  DEVICE_ALT0_VENDOR := SL
  DEVICE_ALT0_MODEL := SL3000
  DEVICE_ALT0_VARIANT := eMMC 1024MB GPT-Fixed
  
  DEVICE_COMPAT_VERSION := 1.0
  DEVICE_DTS := mt7981b-3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  
  # 🎯 物理 ID 严格对齐机器内部 ID
  SUPPORTED_DEVICES := sl,3000-emmc sl,sl3000-emmc mediatek,mt7981
  
  # 🚀 [物理修复] 锁定为 90MB (92160k) 以适配 U-Boot 128MB 分区限制
  KERNEL_SIZE := 92160k
  BOARD_ROOTFS_PARTSIZE := 1024
  
  # 🔥 [U-Boot 识别指纹] 必须使用 uImage 封装
  KERNEL := kernel-bin | lzma | uImage lzma
  KERNEL_INITRAMFS := kernel-bin | lzma | uImage lzma
  
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin factory.bin
  
  # 🎯 [物理锁定] 使用 pad-to $$(KERNEL_SIZE) 进行位移对齐
  IMAGE/sysupgrade.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
