#!/bin/bash
# ============================================================
# SL3000 旗舰版：三件套【检测-修复-注册-合并】合一脚本 V13.5
# ============================================================

echo ">>> [SL3000 工厂模式 V13.5] 启动全链路任务..."

# --- 1. 定位源文件 (资产在仓库根目录) ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTS_SRC="$REPO_ROOT/mt7981b-sl3000-emmc.dts"
MK_SRC="$REPO_ROOT/filogic.mk"
CONF_SRC="$REPO_ROOT/sl3000.config"

# --- 2. 预先注入与路径自愈 ---
# 动态定位内核目录 (适配 ImmortalWrt 25.12)
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"
DTS_DEST="$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

echo ">>> [自愈] 正在修复 DTS 内部头文件引用路径..."
# 核心修复：将本地引用转换为内核标准的系统引用
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    "$DTS_SRC" > "$DTS_DEST"

# --- 3. 深度语法诊断 (Diagnostics) ---
echo ">>> [检测] 正在进行 DTS 语法深度扫描..."
# 动态关联 include 路径，防止报错
DTS_INC="$K_DIR/arch/arm64/boot/dts"
DTS_ERR=$(dtc -I dts -O dtb -p 0 -i "$DTS_INC" -o /dev/null "$DTS_DEST" 2>&1)

if [ $? -ne 0 ]; then
    echo "-------------------------------------------------------"
    echo "❌ 语法校验失败！请根据下方提示修改您的 DTS 文件："
    echo "$DTS_ERR" | grep -E "FATAL ERROR|Error"
    echo "-------------------------------------------------------"
    if echo "$DTS_ERR" | grep -q "syntax error"; then
        exit 1 # 只有真正的语法错误才停止
    fi
fi
echo "✅ DTS 预检通过"

# --- 4. 驱动注册与 Makefile 合并 ---
echo ">>> [注册] 正在同步 Makefile 并补全 eMMC 驱动..."
# 强制补全关键驱动包
if ! grep -q "kmod-mtk-sd" "$MK_SRC"; then
    sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-mtk-sd kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
fi
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 5. 配置合并与 Feeds 优化 ---
echo ">>> [合并] 注入配置参数..."
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_EFI_PARTITION=y"
} >> .config

# 修复插件源与 PHP 递归依赖 (ImmortalWrt 专用)
sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

./scripts/feeds update -a || echo "⚠️ 部分 Feed 更新失败"
./scripts/feeds install -a
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

make defconfig
echo "✅ [任务完成] 环境已就绪！"
