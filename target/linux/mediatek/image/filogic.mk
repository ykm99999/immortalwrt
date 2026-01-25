# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

TARGET_DEVICES += mt7981b-sl3000-emmc

define Device/mt7981b-sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := SL3000 eMMC Engineering Flagship
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_PACKAGES := kmod-mt7981-firmware kmod-fs-ext4 block-mount
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | pad-rootfs | append-metadata
endef
TARGET_DEVICES += mt7981b-sl3000-emmc

