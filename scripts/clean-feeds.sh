#!/bin/bash
set -e

echo ">>> [SL3000 终极版] 启动核心注入系统 V7.8 (Deep-Search Edition)"

# --- 1. 路径锚定 ---
# 获取仓库根目录的绝对路径
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 自动探测配置文件夹
if [ -d "${REPO_ROOT}/sl3000" ]; then
    SEARCH_DIR="${REPO_ROOT}/sl3000"
elif [ -d "${REPO_ROOT}/custom-config" ]; then
    SEARCH_DIR="${REPO_ROOT}/custom-config"
else
    echo "ERROR: 找不到配置目录 sl3000"
    ls -F "$REPO_ROOT"
    exit 1
fi

echo ">>> 正在深度搜索配置源: $SEARCH_DIR"

# --- 2. 深度搜索源文件 (解决嵌套路径问题) ---
# 使用 find 命令递归搜索，无视具体在哪个子目录下
DTS_SRC=$(find "$SEARCH_DIR" -name "mt7981b-sl3000-emmc.dts" | head -n 1)
MK_SRC=$(find "$SEARCH_DIR" -name "filogic.mk" | head -n 1)
CONF_SRC=$(find "$SEARCH_DIR" -name "sl3000.config" | head -n 1)

# 打印搜索结果用于调试
[ -n "$DTS_SRC" ] && echo "找到 DTS: $DTS_SRC" || { echo "缺失 DTS"; exit 1; }
[ -n "$MK_SRC" ] && echo "找到 MK: $MK_SRC" || { echo "缺失 MK"; exit 1; }
[ -n "$CONF_SRC" ] && echo "找到 Config: $CONF_SRC" || { echo "缺失 Config"; exit 1; }

# --- 3. 确定并清理目标路径 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

# --- 4. 物理注入与 Include 语法修正 ---
echo ">>> [对齐] 正在执行多维路径映射..."
DTS_REL_PATHS=(
    "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mediatek/mt7981b-sl3000-emmc.dts"
)

for dts_path in "${DTS_REL_PATHS[@]}"; do
    mkdir -p "$(dirname "$dts_path")"
    sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
        -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
        "$DTS_SRC" > "$dts_path"
done

# --- 5. 编译配置注入 ---
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
sed -i 's/DEVICE_DTS := .*/DEVICE_DTS := mt7981b-sl3000-emmc/' target/linux/mediatek/image/filogic.mk

# --- 6. Feeds 自动化管理 (Passwall 2 & Docker) ---
echo ">>> [源注入] 拉取 Passwall 2 及其依赖..."
sed -i '$a src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' feeds.conf.default
sed -i '$a src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' feeds.conf.default

./scripts/feeds update -a

# 解决 PHP8 循环依赖
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

# 冲突清理
rm -rf package/feeds/luci/luci-app-passwall || true
rm -rf package/feeds/helloworld/luci-app-ssr-plus || true
./scripts/feeds install -a

# --- 7. 最终 .config 补全 ---
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
} >> .config

make defconfig
echo ">>> [成功] V7.8 全链路自愈完成！"
