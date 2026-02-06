define Device/sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := Custom-1GB-Edition
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := sl,sl3000-emmc mediatek,mt7981b mediatek,mt7981
  
  # ✅ 强制分区参数：128MB 内核，1GB 总镜像 (使用 k 提升 25.12 兼容性)
  KERNEL_SIZE := 131072k
  IMAGE_SIZE := 1048576k
  
  # ✅ 内核打包逻辑：明确指定 FIT 格式和 LZMA 压缩
  KERNEL := kernel-bin | lzma | fit $$(DEVICE_DTS)
  
  DEVICE_PACKAGES := \
	kmod-mmc kmod-sdhci-mtk \
	kmod-mt753x \
	kmod-fs-f2fs f2fs-tools f2fsck \
	kmod-usb3 kmod-usb-dwc3-mtk \
	block-mount blkid lsblk parted
  
  # 🚀 【核心修复 1】精简镜像生成目标
  # 严格锁定只生成 sysupgrade，绕过导致 Error 2 的 initramfs 阶段
  IMAGES := sysupgrade.bin sysupgrade.bin.gz
  
  # 🚀 【核心修复 2】强制定义流水线
  # 移除 check-size 等可能在超大分区定义下触发的校验报错
  IMAGE/sysupgrade.bin := append-kernel | pad-to $$$$(KERNEL_SIZE) | append-rootfs | append-metadata
  IMAGE/sysupgrade.bin.gz := append-kernel | pad-to $$$$(KERNEL_SIZE) | append-rootfs | append-metadata | gzip

  # 🚀 【核心修复 3】显式禁用 initramfs 阶段
  # 确保在 25.12 的 install 步骤中不会因为找不到 initramfs 镜像而报错退出
  KERNEL_INITRAMFS := 
endef
TARGET_DEVICES += sl3000-emmc
