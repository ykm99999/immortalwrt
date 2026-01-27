#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCRIPT_DIR="$ROOT/sl3000-tools"
LOG="$SCRIPT_DIR/sl3000-three-piece-master.log"
mkdir -p "$SCRIPT_DIR"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] ROOT = $ROOT"

TAB=$'\t'

###############################################
# 自动探测 mediatek DTS 路径（files-* 最新目录）
###############################################
KVER_DIR="$(cd target/linux/mediatek && ls -d files-* 2>/dev/null | sort | tail -n1 || true)"
if [ -z "$KVER_DIR" ]; then
  echo "[FATAL] target/linux/mediatek/files-* not found"
  exit 1
fi

echo "[INFO] Using mediatek DTS dir: target/linux/mediatek/${KVER_DIR}"

DTS_DIR="$ROOT/target/linux/mediatek/${KVER_DIR}/arch/arm64/boot/dts/mediatek"
DTS="$DTS_DIR/mt7981b-sl3000-emmc.dts"
MK="$ROOT/target/linux/mediatek/image/filogic.mk"
CFG="$ROOT/.config"

mkdir -p "$DTS_DIR"

clean_crlf() { sed -i 's/\r$//' "$1" 2>/dev/null || true; }

###############################################
# Stage 1：生成 DTS（master 兼容，最小可用骨架）
###############################################
echo "=== Stage 1: Generate DTS (master) ==="

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

	chosen {
		stdout-path = "serial0:115200n8";
	};

	leds {
		compatible = "gpio-leds";

		led_status: status {
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

&uart0 {
	status = "okay";
};

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

&switch {
	status = "okay";
};

&pcie {
	status = "okay";
};
EOF

clean_crlf "$DTS"

###############################################
# Stage 2：生成 / 追加 MK 设备段（master 兼容）
###############################################
echo "=== Stage 2: Ensure MK device (master) ==="

if [ ! -f "$MK" ]; then
  echo "[FATAL] $MK not found"
  exit 1
fi

if grep -q "Device/mt7981b-sl3000-emmc" "$MK"; then
  echo "[INFO] Device mt7981b-sl3000-emmc already present in filogic.mk, skip append"
else
  echo "[INFO] Appending mt7981b-sl3000-emmc device to filogic.mk"
  cat >> "$MK" << EOF

define Device/mt7981b-sl3000-emmc
${TAB}DEVICE_VENDOR := SL
${TAB}DEVICE_MODEL := SL3000 eMMC Engineering Flagship
${TAB}DEVICE_DTS := mt7981b-sl3000-emmc
${TAB}DEVICE_DTS_DIR := ../dts
${TAB}DEVICE_PACKAGES := kmod-fs-ext4 block-mount
${TAB}IMAGES := sysupgrade.bin
${TAB}IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += mt7981b-sl3000-emmc
EOF
fi

clean_crlf "$MK"

###############################################
# Stage 3：生成 CONFIG（master 基础配置，留 WiFi 给 master 自己）
###############################################
echo "=== Stage 3: Generate CONFIG (master base) ==="

cat > "$CFG" << 'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_mt7981b-sl3000-emmc=y

# 内核版本由 master 自己选择，不强行锁死
# CONFIG_LINUX_6_12 is not set
# CONFIG_LINUX_6_13 is not set

# 基础 LuCI
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

# 基础存储支持
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_f2fs-tools=y

# 不在这里强行指定 WiFi 驱动，让 master 根据设备 DTS / 依赖自动拉 mt76 / mt7996
EOF

clean_crlf "$CFG"

###############################################
# Stage 4：校验
###############################################
echo "=== Stage 4: Validation ==="

grep -q "mt7981b-sl3000-emmc" "$MK" || { echo "[FATAL] MK missing device"; exit 1; }
grep -q $'\tDEVICE_VENDOR' "$MK" || { echo "[WARN] MK TAB indent check failed (please ensure tabs in Makefile)" ; }
[ -s "$DTS" ] || { echo "[FATAL] DTS missing"; exit 1; }
[ -s "$CFG" ] || { echo "[FATAL] CONFIG missing"; exit 1; }

echo "=== master Three-piece generation complete ==="
echo "[OUT] DTS: $DTS"
echo "[OUT] MK : $MK"
echo "[OUT] CFG: $CFG"
