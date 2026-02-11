define Device/sl3000-emmc
  DEVICE_VENDOR := 司络
  DEVICE_MODEL := SL3000 eMMC
  DEVICE_DTS := mt7981b-sl3000-emmc
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b sl3000-emmc

  KERNEL_SIZE := 134217728
  BOARD_ROOTFS_PARTSIZE := 1024

  # 🎯 物理修复：单 $ 符号
  KERNEL := kernel-bin | lzma | fit $(DEVICE_DTS)
  KERNEL_INITRAMFS :=

  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools parted lsblk blkid block-mount kmod-zram zram-swap

  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata
endef
TARGET_DEVICES += sl3000-emmc
