#!/bin/bash
set -e

echo ">>> [SL3000 终极版] 启动核心注入系统 V8.0 (Final Stable)"

# --- 1. 路径锚定 (根目录回溯) ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEARCH_DIR="${REPO_ROOT}/sl3000"

echo ">>> 锁定配置源: $SEARCH_DIR"

# --- 2. 核心文件提取 ---
# 既然文件名已修复，我们直接定位 (支持 config 子目录搜索)
DTS_SRC=$(find "$SEARCH_DIR" -name "mt7981b-sl3000-emmc.dts" | head -n 1)
MK_SRC=$(find "$SEARCH_DIR" -name "filogic.mk" | head -n 1)
CONF_SRC=$(find "$SEARCH_DIR" -name "sl3000.config" | head -n 1)

# 打印状态，确保万无一失
[ -n "$DTS_SRC" ] && echo "✔ 发现 DTS: $DTS_SRC" || { echo "✘ 错误: 未找到 mt7981b-sl3000-emmc.dts"; exit 1; }
[ -n "$MK_SRC" ] && echo "✔ 发现 MK: $MK_SRC" || { echo "✘ 错误: 未找到 filogic.mk"; exit 1; }
[ -n "$CONF_SRC" ] && echo "✔ 发现 Config: $CONF_SRC" || { echo "✘ 错误: 未找到 sl3000.config"; exit 1; }

# --- 3. 确定内核 files 目录 (适配 6.12 及后续版本) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

# --- 4. 执行 DTS 物理注入与 Include 修正 ---
echo ">>> [注入] 正在对齐设备树路径..."
DTS_REL_PATHS=(
    "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mediatek/mt7981b-sl3000-emmc.dts"
)

for dts_path in "${DTS_REL_PATHS[@]}"; do
    mkdir -p "$(dirname "$dts_path")"
    # 强制将相对引用改为内核标准引用，解决编译报错
    sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
        -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
        "$DTS_SRC" > "$dts_path"
done

# --- 5. Makefile 与 Config 注入 ---
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
sed -i 's/DEVICE_DTS := .*/DEVICE_DTS := mt7981b-sl3000-emmc/' target/linux/mediatek/image/filogic.mk

# --- 6. 插件源注入 (Passwall 2 & Docker) ---
echo ">>> [Feeds] 配置 Passwall 2 及其专用依赖源..."
sed -i '$a src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' feeds.conf.default
sed -i '$a src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' feeds.conf.default

./scripts/feeds update -a

# 解决 Zabbix/PHP 逻辑锁
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

# 清理旧包冲突并安装
rm -rf package/feeds/luci/luci-app-passwall || true
rm -rf package/feeds/helloworld/luci-app-ssr-plus || true
./scripts/feeds install -a

# --- 7. 旗舰版核心参数强制覆盖 ---
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" # 强制 1GB 根分区
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
    echo "CONFIG_PACKAGE_kmod-br-netfilter=y" # Docker 联网核心
} >> .config

make defconfig
echo ">>> [完成] 环境自愈成功，准备开启全核编译！"
