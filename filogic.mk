define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000 (eMMC)
  DEVICE_ALT0_VENDOR := SL
  DEVICE_ALT0_MODEL := SL3000
  DEVICE_ALT0_VARIANT := eMMC 1024MB GPT-Fixed
  
  # 🎯 物理版本锁定：必须为 1.0 以穿透旧系统版本校验
  DEVICE_COMPAT_VERSION := 1.0
  
  # 🎯 内核设备树文件指定
  DEVICE_DTS := mt7981b-3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  
  # 🎯 物理 ID 对齐：严格匹配 cat /tmp/sysinfo/board_name 输出的 [sl,3000-emmc]
  # 增加兼容列表以提高 U-Boot 识别率
  SUPPORTED_DEVICES := sl,3000-emmc sl,sl3000-emmc mediatek,mt7981
  
  # 🚀 [物理硬修复] 128MB 物理填充逻辑 (131072k)
  # 核心目的：使 Rootfs 在固件文件中从 128MB 处开始，完美对齐 GPT 底包预留的偏移
  KERNEL_SIZE := 131072k
  BOARD_ROOTFS_PARTSIZE := 1024
  
  # 🔥 [U-Boot 核心封装] 必须使用 uImage 封装并指定 lzma 压缩
  # 这是 U-Boot 网页端刷机页面识别固件身份的关键指纹
  KERNEL := kernel-bin | lzma | uImage lzma
  KERNEL_INITRAMFS := kernel-bin | lzma | uImage lzma
  
  # 🎯 物理驱动与工具包补齐
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount kmod-zram zram-swap
  
  # 🎯 物理构建清单：sysupgrade 用于系统内更新，factory 用于 U-Boot 底层刷入
  IMAGES := sysupgrade.bin factory.bin
  
  # 🎯 [物理锁定] 严禁修改 pad-to 逻辑
  # 只有这样，Rootfs 才会出现在 GPT 表指定的 128MB 物理地址处
  
  # 1. Sysupgrade 镜像：包含 Metadata 身份证，用于 OpenWrt 系统内升级
  IMAGE/sysupgrade.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs | append-metadata
  
  # 2. Factory 镜像：纯物理镜像，带 uImage 头，专门用于 U-Boot 救砖或初次刷入
  IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
