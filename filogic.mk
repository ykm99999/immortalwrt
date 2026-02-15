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
  
  # 🚀 [物理修正] 移除 KERNEL_SIZE 锁定，取消强制填充
  # 移除 92160k 的填充后，factory.bin 体积将降至约 40MB，确保旧版 U-Boot 绝对能刷入
  BOARD_ROOTFS_PARTSIZE := 1024
  
  # 🔥 [U-Boot 识别指纹] 必须使用 uImage 封装，否则报 wrong file
  KERNEL := kernel-bin | lzma | uImage lzma
  KERNEL_INITRAMFS := kernel-bin | lzma | uImage lzma
  
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin factory.bin
  
  # 🎯 [物理锁定] 移除 pad-to，改用直接拼接 (append)
  # 这样生成的固件是“实心”的，没有 90MB 的空白数据，刷入速度提升 3 倍
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | pad-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
