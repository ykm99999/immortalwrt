define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := sl3000-emmc
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b mediatek,mt7981
  
  # 🎯 延续修复：128MB 内核物理对齐
  KERNEL_SIZE := 134217728
  
  # 🎯 延续修复：彻底解决 root.squashfs Error 1
  BOARD_ROOTFS_PARTSIZE := 524288
  
  # 🎯 延续修复：FIT 镜像打包逻辑
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)
  
  # 🎯 延续修复：核心补丁，禁用救援包防止 Error 2
  KERNEL_INITRAMFS := 
  
  DEVICE_PACKAGES := \
	kmod-mmc kmod-sdhci-mtk \
	kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount \
	kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin
  
  # 🎯 延续修复：物理拼接流水线
  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata
endef
TARGET_DEVICES += sl3000-emmc
