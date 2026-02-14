define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000 (eMMC)
  DEVICE_ALT0_VENDOR := SL
  DEVICE_ALT0_MODEL := SL3000
  DEVICE_ALT0_VARIANT := eMMC GPT Compatible
  
  # 🎯 [物理穿透] 必须为 1.0 才能通过 23.05 GPT 版的校验
  DEVICE_COMPAT_VERSION := 1.0
  
  DEVICE_DTS := mt7981b-3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  
  # 🎯 [物理对齐] 精准匹配您的 cat /tmp/sysinfo/board_name 结果
  SUPPORTED_DEVICES := sl,3000-emmc sl,sl3000-emmc mediatek,mt7981
  
  # GPT 分区下，内核和根分区的数值仅作为编译参考，不再强制填充
  KERNEL_SIZE := 131072k
  BOARD_ROOTFS_PARTSIZE := 1024
  
  KERNEL := kernel-bin | lzma
  KERNEL_INITRAMFS := kernel-bin | lzma
  
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin factory.bin
  # 🎯 [彻底修复] 移除 pad-to，固件体积将恢复到 20MB+，完美通过 GPT 校验
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | pad-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
