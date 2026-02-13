define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000 (eMMC)
  DEVICE_ALT0_VENDOR := SL
  DEVICE_ALT0_MODEL := SL3000
  DEVICE_ALT0_VARIANT := eMMC 1024MB Rootfs
  # 🎯 物理对齐：严格匹配您贴出的 mt7981b-3000-emmc.dts 文件名
  DEVICE_DTS := mt7981b-3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  
  # 🚀 [物理硬修复] 针对您贴出的 DTS 进行路径深钻
  # 修复 fatal error: dt-bindings/gpio/gpio.h: No such file or directory
  DEVICE_DTS_INCLUDE := \
	$(LINUX_DIR)/include \
	$(LINUX_DIR)/scripts/dtc/include-prefixes
  
  SUPPORTED_DEVICES := sl,3000-emmc mediatek,mt7981
  
  # 🎯 物理对齐：您定义的 128MB Kernel (131072k)
  KERNEL_SIZE := 131072k
  # 🎯 物理对齐：您定义的 1024MB Rootfs
  BOARD_ROOTFS_PARTSIZE := 1024
  
  # ⚠️ 逻辑对齐：参考贴出的 DTS，由于是导出的完整配置，必须确保 dtb 物理追加正确
  KERNEL := kernel-bin | lzma | append-dtb
  KERNEL_INITRAMFS := kernel-bin | lzma | append-dtb
  
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck parted lsblk blkid block-mount kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin factory.bin
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | append-rootfs
endef
TARGET_DEVICES += sl3000-emmc
