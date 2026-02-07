define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := sl3000-emmc
  # 🎯 修复：25.12 建议不手动指定 DTS_DIR，让系统自动根据 DEVICE_DTS 查找
  DEVICE_DTS := mt7981b-sl3000-emmc
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b mediatek,mt7981
  
  # 🎯 延续修复：128MB 内核物理对齐 (使用更易读的单位)
  KERNEL_SIZE := 128M
  
  # 🎯 彻底解决 root.squashfs Error 1 (512MB 溢出防御)
  BOARD_ROOTFS_PARTSIZE := 512
  
  # 🎯 修正：25.12 必须使用这种 fit 格式才能正确包含内核
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)
  
  # 🎯 核心补丁：禁用救援包，跳过损坏的 initramfs 流程
  KERNEL_INITRAMFS := 
  
  DEVICE_PACKAGES := \
	kmod-mmc kmod-sdhci-mtk \
	kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount \
	kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin
  
  # 🎯 延续修复：严禁漂移的物理拼接流水线 [内核] + [对齐到128MB] + [Rootfs]
  # 确保 sysupgrade.bin 结构与 eMMC 分区表 1:1 匹配
  IMAGE/sysupgrade.bin := append-kernel | pad-to 128M | append-rootfs | append-metadata
endef
TARGET_DEVICES += sl3000-emmc
