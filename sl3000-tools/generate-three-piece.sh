#!/bin/bash
set -euo pipefail

ROOT="$(pwd)"
SCRIPT_DIR="$ROOT/sl3000-tools"
LOG="$SCRIPT_DIR/sl3000-three-piece.log"
mkdir -p "$SCRIPT_DIR"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

TAB=$'\t'

# DTS 路径保持你设定的 dts 目录
DTS_DIR="$ROOT/target/linux/mediatek/dts"
DTS="$DTS_DIR/mt7981b-sl-3000-emmc.dts"
MK="$ROOT/target/linux/mediatek/image/mt7981.mk"
CFG="$SCRIPT_DIR/sl3000-full-config.txt"

mkdir -p "$DTS_DIR"

echo "=== Stage 1: Generate DTS ==="

cat > "$DTS" << 'EOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT
/dts-v1/;

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/leds/common.h>
#include "mt7981.dtsi"

/ {
	model = "SL-3000 eMMC bootstrap versions";
	compatible = "sl,3000-emmc", "mediatek,mt7981";

	aliases {
		serial0 = &uart0;
		led-boot = &status_red_led;
		led-failsafe = &status_red_led;
		led-running = &status_green_led;
		led-upgrade = &status_blue_led;
	};

	chosen {
		bootargs = "root=PARTLABEL=rootfs rootwait";
		stdout-path = "serial0:115200n8";
	};

	/* 内存 1GB */
	memory@40000000 {
		device_type = "memory";
		reg = <0 0x40000000 0 0x40000000>;
	};

	gpio-keys {
		compatible = "gpio-keys";

		button-mesh {
			label = "mesh";
			linux,code = <BTN_9>;
			linux,input-type = <EV_SW>;
			gpios = <&pio 0 GPIO_ACTIVE_LOW>;
		};

		button-reset {
			label = "reset";
			linux,code = <KEY_RESTART>;
			gpios = <&pio 1 GPIO_ACTIVE_LOW>;
		};
	};

	gpio-leds {
		compatible = "gpio-leds";

		status_red_led: led-0 {
			label = "red:status";
			gpios = <&pio 10 GPIO_ACTIVE_LOW>;
		};

		status_green_led: led-1 {
			label = "green:status";
			gpios = <&pio 11 GPIO_ACTIVE_LOW>;
		};

		status_blue_led: led-2 {
			label = "blue:status";
			gpios = <&pio 12 GPIO_ACTIVE_LOW>;
		};
	};
};

&uart0 { status = "okay"; }
&watchdog { status = "okay"; }
&usb_phy { status = "okay"; }
&xhci { status = "okay"; }

&wifi {
	nvmem-cells = <&eeprom_factory_0>;
	nvmem-cell-names = "eeprom";
	status = "okay";

	band@1 {
		reg = <1>;
		nvmem-cells = <&macaddr_factory_4 1>;
		nvmem-cell-names = "mac-address";
	};
};
EOF

echo "=== Stage 2: Ensure MK device ==="

if ! grep -q "Device/sl-3000-emmc" "$MK"; then
  cat >> "$MK" << EOF

define Device/sl-3000-emmc
${TAB}DEVICE_VENDOR := SL
${TAB}DEVICE_MODEL := SL3000
${TAB}DEVICE_VARIANT := eMMC
${TAB}DEVICE_DTS := mt7981b-sl-3000-emmc
${TAB}DEVICE_DTS_DIR := dts
${TAB}DEVICE_PACKAGES := kmod-usb3 kmod-fs-ext4 block-mount f2fs-tools \\
${TAB}${TAB}luci luci-base luci-i18n-base-zh-cn \\
${TAB}${TAB}luci-app-eqos-mtk luci-app-mtwifi-cfg luci-app-turboacc-mtk luci-app-wrtbwmon
${TAB}IMAGES := sysupgrade.bin
${TAB}IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
${TAB}IMAGE/initramfs.bin := append-dtb | uImage | append-metadata
endef
TARGET_DEVICES += sl-3000-emmc
EOF
fi

echo "=== Stage 3: Generate CONFIG ==="

cat > "$CFG" << 'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_mt7981=y
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_DEVICE_mediatek_mt7981_DEVICE_sl-3000-emmc=y

CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_IMAGES_GZIP=y

CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_f2fs-tools=y

CONFIG_PACKAGE_luci-app-eqos-mtk=y
CONFIG_PACKAGE_luci-app-mtwifi-cfg=y
CONFIG_PACKAGE_luci-app-turboacc-mtk=y
CONFIG_PACKAGE_luci-app-wrtbwmon=y
EOF

echo "=== Stage 4: Validation ==="

[ -s "$DTS" ] || { echo "[FATAL] DTS missing"; exit 1; }
[ -s "$MK" ]  || { echo "[FATAL] MK missing"; exit 1; }
[ -s "$CFG" ] || { echo "[FATAL] CONFIG missing"; exit 1; }

echo "=== Three-piece generation complete (25.12, SL-3000 eMMC) ==="
echo "[OUT] DTS: $DTS"
echo "[OUT] MK : $MK"
echo "[OUT] CFG: $CFG"
