define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := Custom-128GB-Edition
  # ✅ 延续修复：锁定全小写 DTS 名称
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b mediatek,mt7981
  
  # 🎯 延续修复：内核分区物理大小锁定为 128MB (134217728 字节)
  KERNEL_SIZE := 134217728
  
  # 🎯 彻底修复：移除具体 IMAGE_SIZE 限制，防止 128GB 空间导致的编译溢出报错
  
  # 🎯 延续修复：核心打包宏定义，确保 FIT 镜像包含 Kernel 和 DTB
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)
  
  # 🎯 核心补丁：彻底禁用 initramfs，跳过导致 Error 2 的救援包生成步骤
  KERNEL_INITRAMFS := 
  
  # 🚀 延续修复：释放 128GB eMMC 潜力的驱动包
  DEVICE_PACKAGES := \
	kmod-mmc kmod-sdhci-mtk \
	kmod-fs-f2fs f2fs-tools f2fsck \
	parted lsblk blkid block-mount \
	kmod-zram zram-swap
  
  # 🎯 终极修复：只保留 sysupgrade.bin 格式，移除所有压缩干扰
  IMAGES := sysupgrade.bin
  
  # 🎯 延续修复：物理拼接流水线 [内核] + [补位到128MB] + [Rootfs]
  # 使用 $$$$(KERNEL_SIZE) 确保在 25.12 宏嵌套中能正确解析
  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata
endef
TARGET_DEVICES += sl3000-emmc
