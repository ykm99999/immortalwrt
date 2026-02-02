#!/bin/bash
# ============================================================
# SL3000 工厂初始化脚本 V13.6 (printf 全框架还原版)
# 功能：生成包含完整 GPT 逻辑的 Makefile 并覆盖官方源
# ============================================================

DTS_OUT="./mt7981b-sl3000-emmc.dts"
MK_OUT="./filogic.mk"
CFG_OUT="./sl3000.config"

echo ">>> [SL3000] 开始生成包含官方架构框架的完整资产..."

# --- 1. 生成 DTS (精简关键节点) ---
printf "/dts-v1/;\n#include <dt-bindings/gpio/gpio.h>\n#include <dt-bindings/input/input.h>\n#include <dt-bindings/leds/common.h>\n#include <mediatek/mt7981.dtsi>\n\n" > $DTS_OUT
printf "/ {\n\tmodel = \"SL-3000 eMMC Router\";\n\tcompatible = \"sl,sl3000-emmc\", \"mediatek,mt7981b\";\n" >> $DTS_OUT
printf "\tmemory@40000000 {\n\t\tdevice_type = \"memory\";\n\t\treg = <0x0 0x40000000 0x0 0x40000000>;\n\t};\n};\n" >> $DTS_OUT
printf "&uart0 { status = \"okay\"; };\n&mmc0 { status = \"okay\"; bus-width = <8>; non-removable; };\n" >> $DTS_OUT

# --- 2. 生成 Makefile (完整框架：含 GPT、Metadata、Device 定义) ---
# 注意：使用 %s 配合单引号，防止 Shell 误解析 $ 符号
printf 'DTS_DIR := $(DTS_DIR)/mediatek\n\n' > $MK_OUT
printf 'define Image/Prepare\n\trm -f $(KDIR)/ubi_mark\n\techo -ne "\\xde\\xad\\xc0\\xde" > $(KDIR)/ubi_mark\nendef\n\n' >> $MK_OUT
printf 'define Build/mt7981-bl2\n\tcat $(STAGING_DIR_IMAGE)/mt7981-$(1)-bl2.img >> $@\nendef\n\n' >> $MK_OUT
printf 'define Build/mt7981-bl31-uboot\n\tcat $(STAGING_DIR_IMAGE)/mt7981_$(1)-u-boot.fip >> $@\nendef\n\n' >> $MK_OUT

# 注入你最核心的 GPT 分区生成逻辑
printf 'define Build/mt798x-gpt\n' >> $MK_OUT
printf '\tcp $@ $@.tmp 2>/dev/null || true\n' >> $MK_OUT
printf '\tptgen -g -o $@.tmp -a 1 -l 1024 \\\n' >> $MK_OUT
printf '\t\t$(if $(findstring sdmmc,$(1)), -H -t 0x83 -N bl2 -r -p 4079k@17k ) \\\n' >> $MK_OUT
printf '\t\t-t 0x83 -N ubootenv -r -p 512k@4M \\\n' >> $MK_OUT
printf '\t\t-t 0x83 -N factory -r -p 2M@4608k \\\n' >> $MK_OUT
printf '\t\t-t 0xef -N fip -r -p 4M@6656k \\\n' >> $MK_OUT
printf '\t\t-N recovery -r -p 32M@12M \\\n' >> $MK_OUT
printf '\t\t$(if $(findstring sdmmc,$(1)), -N install -r -p 20M@44M -t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M ) \\\n' >> $MK_OUT
printf '\t\t$(if $(findstring emmc,$(1)), -t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M )\n' >> $MK_OUT
printf '\tcat $@.tmp >> $@\n\trm $@.tmp\nendef\n\n' >> $MK_OUT

# 注入元数据与设备定义
printf 'define Build/append-gl-metadata\n\tsha256sum "$@" | cut -d" " -f1 > "$@.sha256sum"\nendef\n\n' >> $MK_OUT
printf 'define Device/sl3000-emmc\n  DEVICE_VENDOR := SL\n  DEVICE_MODEL := SL3000\n  DEVICE_VARIANT := eMMC\n  DEVICE_DTS := mt7981b-sl3000-emmc\n  DEVICE_DTS_DIR := $(DTS_DIR)\n  SUPPORTED_DEVICES := sl,sl3000-emmc\n' >> $MK_OUT
printf '  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware kmod-usb3 kmod-usb-dwc3-mtk kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools\n' >> $MK_OUT
printf '  IMAGES := sysupgrade.itb factory.bin\n' >> $MK_OUT
printf '  IMAGE/sysupgrade.itb := append-kernel | append-dtb | append-metadata\n' >> $MK_OUT
printf '  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt emmc | append-gl-metadata\nendef\n' >> $MK_OUT
printf 'TARGET_DEVICES += sl3000-emmc\n' >> $MK_OUT

# --- 3. 生成 Config ---
printf "CONFIG_TARGET_mediatek=y\nCONFIG_TARGET_mediatek_filogic=y\nCONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y\nCONFIG_TARGET_ROOTFS_PARTSIZE=1024\n" > $CFG_OUT

echo "✅ [完成] 包含官方架构框架的 MK 文件已生成，可直接覆盖源文件。"
