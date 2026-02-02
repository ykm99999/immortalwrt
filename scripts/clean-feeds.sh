#!/bin/bash
set -e

echo ">>> [SL3000 终极版] 启动核心注入系统 V7.6 (Path-Safe Edition)"

# --- 1. 路径绝对化处理 ---
# 获取脚本所在目录的父目录，即仓库根目录
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# 强制定义配置文件夹路径
SRC_DIR="${REPO_ROOT}/custom-config"

echo ">>> 仓库根目录: $REPO_ROOT"
echo ">>> 配置源目录: $SRC_DIR"

# 检查目录是否存在
if [ ! -d "$SRC_DIR" ]; then
    echo "ERROR: 找不到配置目录 $SRC_DIR"
    echo "当前目录结构如下:"
    ls -R "$REPO_ROOT"
    exit 1
fi

# --- 2. 源文件精准锁定 ---
DTS_SRC=$(find "$SRC_DIR" -name "mt7981b-sl3000-emmc.dts" | head -n 1)
MK_SRC=$(find "$SRC_DIR" -name "filogic.mk" | head -n 1)
CONF_SRC=$(find "$SRC_DIR" -name "sl3000.config" | head -n 1)

# 阻断检查
if [ -z "$DTS_SRC" ] || [ -z "$MK_SRC" ] || [ -z "$CONF_SRC" ]; then
    echo "FATAL: custom-config 目录下缺失核心三件套文件！"
    exit 1
fi

# --- 3. 确定内核 DTS 存放路径 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

# --- 4. 物理注入与 Include 修正 ---
echo ">>> [对齐] 正在执行多维路径映射..."
DTS_REL_PATHS=(
    "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mediatek/mt7981b-sl3000-emmc.dts"
)

for dts_path in "${DTS_REL_PATHS[@]}"; do
    mkdir -p "$(dirname "$dts_path")"
    # 核心修正：确保设备树内部 include 路径兼容内核全局搜索
    sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
        -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
        "$DTS_SRC" > "$dts_path"
done

# --- 5. 编译配置注入 ---
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
# 确保 Makefile 中的设备名不带路径污染
sed -i 's/DEVICE_DTS := .*/DEVICE_DTS := mt7981b-sl3000-emmc/' target/linux/mediatek/image/filogic.mk

# --- 6. Feeds 自动化管理 ---
echo ">>> [源注入] 正在拉取 Passwall 2 及依赖..."
sed -i '$a src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' feeds.conf.default
sed -i '$a src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' feeds.conf.default

./scripts/feeds update -a

# 解决 Zabbix/PHP8 循环依赖
if [ -d "feeds/packages/admin/zabbix" ]; then
    find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +
fi

# 移除旧版冲突，安装新包
rm -rf package/feeds/luci/luci-app-passwall || true
rm -rf package/feeds/helloworld/luci-app-ssr-plus || true
./scripts/feeds install -a

# --- 7. 强制补全 .config 核心参数 (Docker + 1GB RAM) ---
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_kmod-br-netfilter=y"
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
} >> .config

make defconfig
echo ">>> [成功] V7.6 全路径自愈完成！"
