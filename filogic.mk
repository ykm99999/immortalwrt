define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000 (eMMC)
  DEVICE_ALT0_VENDOR := SL
  DEVICE_ALT0_MODEL := SL3000
  DEVICE_ALT0_VARIANT := eMMC 1024MB Rootfs
  
  # 🎯 [物理兼容性修复] 强行标记为 1.0，允许从 23.05 (Legacy) 系统物理刷入
  DEVICE_COMPAT_VERSION := 1.0
  
  DEVICE_DTS := mt7981b-3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  
  # 🎯 [ID 物理对齐] 同时锁定新旧两个 ID，彻底解决 "Image check failed"
  SUPPORTED_DEVICES := sl,3000-emmc sl,sl3000-emmc mediatek,mt7981
  
  # 🚀 [物理硬修复] 彻底舍弃十六进制，使用 dd 识别的十进制字节单位 (128MB)
  KERNEL_SIZE := 131072k
  # 🎯 Rootfs 物理对齐 (1024MB)
  BOARD_ROOTFS_PARTSIZE := 1024
  
  KERNEL := kernel-bin | lzma
  KERNEL_INITRAMFS := kernel-bin | lzma
  
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin factory.bin
  # 🎯 物理熔断：使用 $$(KERNEL_SIZE) 确保 dd 填充 128MB 物理空洞
  IMAGE/sysupgrade.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
