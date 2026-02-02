#!/bin/bash
# ============================================================
# SL3000 旗舰初始化脚本 V14.5 (无USB + eMMC完整版)
# ============================================================

# 自动定位仓库根目录
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

DTS_OUT="mt7981b-sl3000-emmc.dts"
MK_OUT="filogic.mk"
CFG_OUT="sl3000.config"

echo ">>> [SL3000] 正在生成定制化三件套..."

# --- 1. 生成 DTS (针对无USB硬件优化) ---
cat << 'EOF' > "$DTS_OUT"
/dts-v1/;
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/leds/common.h>
#include <mediatek/mt7981.dtsi>

/ {
	model = "SL-3000 eMMC Router";
	compatible = "sl,sl3000-emmc", "mediatek,mt7981b";

	aliases {
		serial0 = &uart0;
		led-boot = &led_green;
		led-failsafe = &led_red;
		led-running = &led_green;
		led-upgrade = &led_blue;
	};

	chosen {
		stdout-path = "serial0:115200n8";
		bootargs = "root=PARTLABEL=production rootwait";
	};

	memory@40000000 {
		device_type = "memory";
		reg = <0x0 0x40000000 0x0 0x40000000>;
	};

	reg_3p3v: regulator-3p3v {
		compatible = "regulator-fixed";
		regulator-name = "fixed-3.3V";
		regulator-min-microvolt = <3300000>;
		regulator-max-microvolt = <3300000>;
		regulator-boot-on;
		regulator-always-on;
	};
};

&uart0 { status = "okay"; };
&watchdog { status = "okay"; };
&wifi { status = "okay"; };

/* 彻底禁用 USB 节点以节省资源 */
&usb_phy { status = "disabled"; };
&xhci { status = "disabled"; };

&mmc0 {
	bus-width = <8>;
	cap-mmc-highspeed;
	cap-mmc-hw-reset;
	max-frequency = <52000000>;
	non-removable;
	vmmc-supply = <&reg_3p3v>;
	status = "okay";
};
EOF

# --- 2. 生成 Makefile (覆盖官方框架 + GPT分区) ---
cat << 'EOF' > "$MK_OUT"
DTS_DIR := $(DTS_DIR)/mediatek

define Image/Prepare
	echo -ne '\xde\xad\xc0\xde' > $(KDIR)/ubi_mark
endef

define Build/mt7981-bl2
	cat $(STAGING_DIR_IMAGE)/mt7981-$(1)-bl2.img >> $@
endef

define Build/mt798x-gpt
	cp $@ $@.tmp 2>/dev/null || true
	ptgen -g -o $@.tmp -a 1 -l 1024 \
		-t 0x83 -N ubootenv -r -p 512k@4M \
		-t 0x83 -N factory -r -p 2M@4608k \
		-t 0xef -N fip -r -p 4M@6656k \
		-N recovery -r -p 32M@12M \
		-t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M
	cat $@.tmp >> $@
	rm $@.tmp
endef

define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := SL3000
  DEVICE_VARIANT := eMMC
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := $(DTS_DIR)
  SUPPORTED_DEVICES := sl,sl3000-emmc
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools
  IMAGES := sysupgrade.itb factory.bin
  IMAGE/sysupgrade.itb := append-kernel | append-dtb | append-metadata
  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt emmc
endef
TARGET_DEVICES += sl3000-emmc
EOF

# --- 3. 生成 Config (完整软件包补全) ---
cat << 'EOF' > "$CFG_OUT"
# 核心架构定义
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y

# eMMC 启动与分区支持
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
CONFIG_EFI_PARTITION=y
CONFIG_PACKAGE_kmod-mmc=y
CONFIG_PACKAGE_kmod-sdhci-mtk=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_f2fs-tools=y

# 无线核心 (无USB驱动)
CONFIG_PACKAGE_kmod-mt7915e=y
CONFIG_PACKAGE_kmod-mt7981-firmware=y
CONFIG_PACKAGE_mt7981-wo-firmware=y

# 必备管理界面
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-app-ttyd=y
EOF

# 统一换行符并清理
sed -i 's/\r//g' "$DTS_OUT" "$MK_OUT" "$CFG_OUT"

echo ">>> [成功] 文件行数校验:"
wc -l "$DTS_OUT" "$MK_OUT" "$CFG_OUT"
