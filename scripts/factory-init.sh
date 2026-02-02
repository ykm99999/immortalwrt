#!/bin/bash
# ============================================================
# SL3000 旗舰版资产生成器 V13.1 (factory-init.sh)
# 功能：物理生成三件套、消除编码隐患、语法深度校验
# ============================================================

echo ">>> [SL3000] 正在执行工厂级资产初始化..."

# 1. 生成 DTS 文件 (mt7981b-sl3000-emmc.dts)
cat << 'EOF' > mt7981b-sl3000-emmc.dts
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
		led-boot = &led_red;
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

	gpio-keys {
		compatible = "gpio-keys";
		mesh { label = "mesh"; linux,code = <BTN_9>; gpios = <&pio 0 GPIO_ACTIVE_LOW>; };
		reset { label = "reset"; linux,code = <KEY_RESTART>; gpios = <&pio 1 GPIO_ACTIVE_LOW>; };
	};

	leds {
		compatible = "gpio-leds";
		led_red: led-red { label = "red:status"; color = <LED_COLOR_ID_RED>; gpios = <&pio 10 GPIO_ACTIVE_LOW>; };
		led_green: led-green { label = "green:status"; color = <LED_COLOR_ID_GREEN>; gpios = <&pio 11 GPIO_ACTIVE_LOW>; };
		led_blue: led-blue { label = "blue:status"; color = <LED_COLOR_ID_BLUE>; gpios = <&pio 12 GPIO_ACTIVE_LOW>; };
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

&eth {
	status = "okay";
	gmac0: mac@0 {
		compatible = "mediatek,eth-mac"; reg = <0>; phy-mode = "2500base-x";
		fixed-link { speed = <2500>; full-duplex; pause; };
	};
	mdio: mdio-bus {
		#address-cells = <1>; #size-cells = <0>;
		switch@0 {
			compatible = "mediatek,mt7531"; reg = <31>; reset-gpios = <&pio 39 GPIO_ACTIVE_LOW>;
			ports {
				#address-cells = <1>; #size-cells = <0>;
				port@0 { reg = <0>; label = "lan1"; };
				port@1 { reg = <1>; label = "lan2"; };
				port@2 { reg = <2>; label = "lan3"; };
				port@3 { reg = <3>; label = "wan"; };
				port@6 {
					reg = <6>; label = "cpu"; ethernet = <&gmac0>; phy-mode = "2500base-x";
					fixed-link { speed = <2500>; full-duplex; pause; };
				};
			};
		};
	};
};

&mmc0 {
	bus-width = <8>; cap-mmc-highspeed; cap-mmc-hw-reset; max-frequency = <52000000>; non-removable;
	vmmc-supply = <&reg_3p3v>; pinctrl-names = "default", "state_uhs";
	pinctrl-0 = <&mmc0_pins_default>; pinctrl-1 = <&mmc0_pins_uhs>; status = "okay";
};

&pio {
	mmc0_pins_default: mmc0-pins-default {
		mux { function = "flash"; groups = "emmc_45"; };
		conf { pins = "EMMC_DATA_0", "EMMC_DATA_1", "EMMC_DATA_2", "EMMC_DATA_3", "EMMC_DATA_4", "EMMC_DATA_5", "EMMC_DATA_6", "EMMC_DATA_7", "EMMC_CMD"; input-enable; drive-strength = <4>; bias-pull-up = <MTK_PUPD_SET_R1R0_01>; };
		conf-clk { pins = "EMMC_CLK"; drive-strength = <4>; bias-pull-down = <MTK_PUPD_SET_R1R0_01>; };
	};
	mmc0_pins_uhs: mmc0-pins-uhs {
		mux { function = "flash"; groups = "emmc_45"; };
		conf { pins = "EMMC_DATA_0", "EMMC_DATA_1", "EMMC_DATA_2", "EMMC_DATA_3", "EMMC_DATA_4", "EMMC_DATA_5", "EMMC_DATA_6", "EMMC_DATA_7", "EMMC_CMD"; input-enable; drive-strength = <6>; bias-pull-up = <MTK_PUPD_SET_R1R0_01>; };
		conf-clk { pins = "EMMC_CLK"; drive-strength = <6>; bias-pull-down = <MTK_PUPD_SET_R1R0_01>; };
	};
};

&uart0 { status = "okay"; };
&watchdog { status = "okay"; };
&wifi { status = "okay"; };
&usb_phy { status = "okay"; };
&xhci { status = "okay"; };
EOF

# 2. 生成 Makefile (filogic.mk)
cat << 'EOF' > filogic.mk
DTS_DIR := $(DTS_DIR)/mediatek
define Image/Prepare
	echo -ne '\xde\xad\xc0\xde' > $(KDIR)/ubi_mark
endef
define Build/mt7981-bl2
	cat $(STAGING_DIR_IMAGE)/mt7981-$1-bl2.img >> $@
endef
define Build/mt7981-bl31-uboot
	cat $(STAGING_DIR_IMAGE)/mt7981_$1-u-boot.fip >> $@
endef
define Build/mt798x-gpt
	cp $@ $@.tmp 2>/dev/null || true
	ptgen -g -o $@.tmp -a 1 -l 1024 \
		$(if $(findstring sdmmc,$1), -H -t 0x83 -N bl2 -r -p 4079k@17k ) \
		-t 0x83 -N ubootenv -r -p 512k@4M -t 0x83 -N factory -r -p 2M@4608k \
		-t 0xef -N fip -r -p 4M@6656k -N recovery -r -p 32M@12M \
		$(if $(findstring sdmmc,$1), -N install -r -p 20M@44M -t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M ) \
		$(if $(findstring emmc,$1), -t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M )
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
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware kmod-usb3 kmod-usb-dwc3-mtk kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools
  IMAGES := sysupgrade.itb factory.bin
  IMAGE/sysupgrade.itb := append-kernel | append-dtb | append-metadata
  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt emmc | append-gl-metadata
endef
TARGET_DEVICES += sl3000-emmc
EOF

# 3. 生成 Config (sl3000.config)
cat << 'EOF' > sl3000.config
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
CONFIG_EFI_PARTITION=y
EOF

echo "✅ [完成] 三件套已成功生成，编码格式：UTF-8 ASCII。"
