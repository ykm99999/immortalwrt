#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCRIPT_DIR="$ROOT/sl3000-tools"
LOG="$SCRIPT_DIR/sl3000-three-piece-2512.log"
mkdir -p "$SCRIPT_DIR"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] ROOT = $ROOT"

###############################################
# 25.12 固定路径
###############################################
DTS_DIR="$ROOT/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
DTS="$DTS_DIR/mt7981b-sl3000-emmc.dts"
MK="$ROOT/target/linux/mediatek/image/filogic.mk"
CFG="$ROOT/.config"

mkdir -p "$DTS_DIR"

clean_crlf() { sed -i 's/\r$//' "$1" 2>/dev/null || true; }

###############################################
# Stage 1：生成 DTS（25.12 兼容）
###############################################
echo "=== Stage 1: Generate DTS ==="

cat > "$DTS" << 'EOF'
// SPDX-License-Identifier: GPL-2.0-only OR MIT
/dts-v1/;

#include "mt7981.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/leds/common.h>

/ {
    model = "SL3000 eMMC Engineering Flagship";
    compatible = "sl,sl3000-emmc", "mediatek,mt7981b";

    aliases {
        serial0 = &uart0;
        led-boot = &led_status;
        led-failsafe = &led_status;
        led-running = &led_status;
        led-upgrade = &led_status;
    };

    chosen { stdout-path = "serial0:115200n8"; };

    leds {
        compatible = "gpio-leds";
        status: led-0 {
            label = "sl:blue:status";
            gpios = <&pio 12 GPIO_ACTIVE_LOW>;
            linux,default-trigger = "heartbeat";
            default-state = "on";
        };
    };

    keys {
        compatible = "gpio-keys";
        reset {
            label = "reset";
            gpios = <&pio 18 GPIO_ACTIVE_LOW>;
            linux,code = <KEY_RESTART>;
            debounce-interval = <60>;
        };
    };
};

&uart0 { status = "okay"; };

&mmc {
    status = "okay";
    bus-width = <8>;
    mmc-hs200-1_8v;
    non-removable;
    cap-mmc-hw-reset;
};

&gmac0 {
    status = "okay";
    phy-mode = "2500base-x";
    phy-handle = <&phy0>;
};

&switch { status = "okay"; };

&pcie { status = "okay"; };
EOF

clean_crlf "$DTS"

###############################################
# Stage 2：生成 MK（保留官方结构 + 删除所有设备 + 添加 SL3000）
###############################################
echo "=== Stage 2: Generate MK (25.12 official structure) ==="

cat > "$MK" << 'EOF'
DTS_DIR := $(DTS_DIR)/mediatek
DEVICE_VARS += SUPPORTED_TELTONIKA_DEVICES
DEVICE_VARS += SUPPORTED_TELTONIKA_HW_MODS

define Image/Prepare
	rm -f $(KDIR)/ubi_mark
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
		-t 0x83 -N ubootenv -r -p 512k@4M \
		-t 0x83 -N factory   -r -p 2M@4608k \
		-t 0xef -N fip       -r -p 4M@6656k \
		-N recovery          -r -p 32M@12M \
		-t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M
	cat $@.tmp >> $@
	rm $@.tmp
endef

###########################################################
# ONLY DEVICE: SL3000 (25.12 风格)
###########################################################
define Device/mt7981b-sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := SL3000 eMMC Engineering Flagship
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7981-firmware kmod-fs-ext4 block-mount
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += mt7981b-sl3000-emmc
EOF

clean_crlf "$MK"

###############################################
# Stage 3：生成 CONFIG（25.12 兼容）
###############################################
echo "=== Stage 3: Generate CONFIG ==="

cat > "$CFG" << 'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_mt7981b-sl3000-emmc=y

CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

CONFIG_PACKAGE_luci-app-passwall2=y
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_v2ray-core=y
CONFIG_PACKAGE_hysteria2=y

CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_containerd=y
CONFIG_PACKAGE_runc=y

CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_f2fs-tools=y

CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

clean_crlf "$CFG"

###############################################
# Stage 4：校验
###############################################
echo "=== Stage 4: Validation ==="

grep -q "mt7981b-sl3000-emmc" "$MK" || { echo "[FATAL] MK missing device"; exit 1; }
[ -s "$DTS" ] || { echo "[FATAL] DTS missing"; exit 1; }
[ -s "$CFG" ] || { echo "[FATAL] CONFIG missing"; exit 1; }

echo "=== 25.12 Three-piece generation complete ==="
echo "[OUT] DTS: $DTS"
echo "[OUT] MK : $MK"
echo "[OUT] CFG: $CFG"
