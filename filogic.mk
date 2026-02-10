# SPDX-License-Identifier: GPL-2.0-only
#
# MediaTek Filogic 820/830 (MT7981B)
# SL3000 eMMC 完整设备定义

define Device/sl3000-emmc
  DEVICE_VENDOR := 司络
  DEVICE_MODEL := SL3000 eMMC
  DEVICE_DTS := mt7981b-sl3000-emmc
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b sl3000-emmc

  # 内核大小：128MB (字节数)
  KERNEL_SIZE := 134217728

  # 根文件系统大小：1024MB (与 .config 保持一致)
  BOARD_ROOTFS_PARTSIZE := 1024

  # 内核编译流水线
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)

  # 禁用 initramfs
  KERNEL_INITRAMFS :=

  # eMMC + 文件系统 + 分区工具 完整包
  DEVICE_PACKAGES := \
    kmod-mmc \
    kmod-sdhci-mtk \
    kmod-fs-f2fs \
    f2fs-tools \
    parted \
    lsblk \
    blkid \
    block-mount \
    kmod-zram \
    zram-swap

  # 输出固件
  IMAGES := sysupgrade.bin

  # 拼接规则：内核 → 对齐128MB → rootfs → 元数据
  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata
endef
TARGET_DEVICES += sl3000-emmc
