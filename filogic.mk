# SPDX-License-Identifier: GPL-2.0-only
#
# MediaTek Filogic 820/830 (MT7981B)
# SL3000 eMMC 完整设备定义

define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := sl3000-emmc
  DEVICE_DTS := mt7981b-sl3000-emmc
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b

  # 内核大小：128MB（字节数，避免 128M 语法错误）
  KERNEL_SIZE :=134217728

  # 根文件系统大小 512MB
  BOARD_ROOTFS_PARTSIZE := 512

  # 内核编译流水线
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)

  # 禁用 initramfs 避免报错
  KERNEL_INITRAMFS :=

  # eMMC + 文件系统 + 分区工具 完整包
  DEVICE_PACKAGES := \
    kmod-mmc \
    kmod-sdhci-mtk \
    kmod-fs-f2fs \
    f2fs-tools \
    f2fsck \
    parted \
    lsblk \
    blkid \
    block-mount \
    kmod-zram \
    zram-swap

  # 输出固件
  IMAGES := sysupgrade.bin

  # 拼接规则：内核 → 对齐128MB → rootfs → 元数据
  # 全部使用字节数，彻底解决 bash: 128M value too great for base
  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata
endef
TARGET_DEVICES += sl3000-emmc
