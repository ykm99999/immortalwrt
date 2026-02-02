#!/bin/bash
# ============================================================
# SL3000 旗舰初始化脚本 V14.6 (根目录锁定版)
# ============================================================

# 强行定位仓库根目录
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

echo ">>> 目标输出目录: $REPO_ROOT"

# 定义绝对路径
DTS_OUT="$REPO_ROOT/mt7981b-sl3000-emmc.dts"
MK_OUT="$REPO_ROOT/filogic.mk"
CFG_OUT="$REPO_ROOT/sl3000.config"

# 1. 生成 DTS (无USB优化)
cat << 'EOF' > "$DTS_OUT"
/dts-v1/;
#include <dt-bindings/gpio/gpio.h>
#include <mediatek/mt7981.dtsi>
/ {
	model = "SL-3000 eMMC Router";
	compatible = "sl,sl3000-emmc", "mediatek,mt7981b";
	memory@40000000 { device_type = "memory"; reg = <0x0 0x40000000 0x0 0x40000000>; };
};
&uart0 { status = "okay"; };
&mmc0 { status = "okay"; bus-width = <8>; non-removable; };
EOF

# 2. 生成 Makefile (GPT框架)
cat << 'EOF' > "$MK_OUT"
DTS_DIR := $(DTS_DIR)/mediatek
define Build/mt798x-gpt
	cp $@ $@.tmp 2>/dev/null || true
	ptgen -g -o $@.tmp -a 1 -l 1024 \
		-t 0x83 -N ubootenv -r -p 512k@4M \
		-t 0xef -N fip -r -p 4M@6656k \
		-t 0x2e -N production -p $(CONFIG_TARGET_ROOTFS_PARTSIZE)M@64M
	cat $@.tmp >> $@
	rm $@.tmp
endef
define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := SL3000
  DEVICE_DTS := mt7981b-sl3000-emmc
  DEVICE_PACKAGES := kmod-mmc kmod-mtk-sd kmod-fs-f2fs f2fs-tools
  IMAGE/factory.bin := append-rootfs | pad-rootfs | mt798x-gpt emmc
endef
TARGET_DEVICES += sl3000-emmc
EOF

# 3. 生成 Config (补全核心依赖)
cat << 'EOF' > "$CFG_OUT"
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_f2fs-tools=y
EOF

# 统一换行符
sed -i 's/\r//g' "$DTS_OUT" "$MK_OUT" "$CFG_OUT"
echo ">>> [成功] 物理文件已确认:"
ls -l "$DTS_OUT" "$MK_OUT" "$CFG_OUT"

