# ============================================================
# MediaTek Filogic 平台设备定义 (SL3000 旗舰修复版)
# ============================================================

# 修正 DTS 搜索路径，确保 Kernel 6.12 兼容
DTS_DIR := $(DTS_DIR)/mediatek

define Image/Prepare
	# 为 UBI 分区准备空块
	rm -f $(KDIR)/ubi_mark
	echo -ne '\xde\xad\xc0\xde' > $(KDIR)/ubi_mark
endef

# --- 基础构建步骤定义 ---

define Build/mt7981-bl2
	cat $(STAGING_DIR_IMAGE)/mt7981-$1-bl2.img >> $@
endef

define Build/mt7981-bl31-uboot
	cat $(STAGING_DIR_IMAGE)/mt7981_$1-u-boot.fip >> $@
endef

# GPT 分区表生成逻辑 (128GB eMMC 适配)
define Build/mt798x-gpt
	cp $@ $@.tmp 2>/dev/null || true
	ptgen -g -o $@.tmp -a 1 -l 1024 \
		$(if $(findstring sdmmc,$1), \
			-H \
			-t 0x83	-N bl2		-r	-p 4079k@17k \
		) \
			-t 0x83	-N ubootenv	-r	-p 512k@4M \
			-t 0x83	-N factory	-r	-p 2M@4608k \
			-t 0xef	-N fip		-r	-p 4M@6656k \
				-N recovery	-r	-p 32M@12M \
		$(if $(findstring sdmmc,$1), \
				-N install	-r	-p 20M@44M \
			-t 0x2e -N production		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M \
		) \
		$(if $(findstring emmc,$1), \
			-t 0x2e -N production		-p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M \
		)
	cat $@.tmp >> $@
	rm $@.tmp
endef

# GL 格式 Metadata 生成 (用于后台识别与 SHA256 校验)
metadata_gl_json = \
	'{ $(if $(IMAGE_METADATA),$(IMAGE_METADATA)$(comma)) \
		"metadata_version": "1.1", \
		"compat_version": "1.0", \
		"version": { \
			"release": "$(call json_quote,$(VERSION_NUMBER))", \
			"date": "$(shell TZ='Asia/Shanghai' date '+%Y%m%d%H%M%S')", \
			"dist": "$(call json_quote,$(VERSION_DIST))", \
			"target": "$(call json_quote,$(TARGETID))", \
			"board": "$(call json_quote,$(if $(BOARD_NAME),$(BOARD_NAME),$(DEVICE_NAME)))" \
		} \
	}'

define Build/append-gl-metadata
	$(if $(SUPPORTED_DEVICES),-echo $(call metadata_gl_json,$(SUPPORTED_DEVICES)) | fwtool -I - $@)
	sha256sum "$@" | cut -d" " -f1 > "$@.sha256sum"
endef

# ============================================================
# SL3000 eMMC 设备定义 (核心修复区)
# ============================================================

define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := SL3000
  DEVICE_VARIANT := eMMC
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)
  SUPPORTED_DEVICES := sl,sl3000-emmc
  
  # 预装核心驱动 (eMMC + WiFi + USB3)
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware \
	kmod-usb3 kmod-usb-dwc3-mtk kmod-mmc kmod-sdhci-mtk
  
  IMAGES := sysupgrade.itb factory.bin
  
  # ITB 用于 sysupgrade: 合并内核、DTS 和元数据
  IMAGE/sysupgrade.itb := append-kernel | append-dtb | append-metadata
  
  # Factory 用于初次刷机: 必须构建完整的磁盘镜像 (GPT + BL2 + FIP + Rootfs)
  # 这里的逻辑：先生成 rootfs，然后调用 mt798x-gpt 包装分区表
  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt emmc | append-gl-metadata
endef

TARGET_DEVICES += sl3000-emmc
