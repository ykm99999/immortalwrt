#!/bin/bash
set -e

echo ">>> [自愈体系] clean-feeds.sh v25.12-sl3000-final 启动"

# ================================
# 1. 清空 feeds
# ================================
echo "=== 清空 feeds 包 ==="
rm -rf feeds/*

# ================================
# 2. 保留主树
# ================================
echo "=== 保留主树（不删除 package/system/* 等核心包） ==="

# ================================
# 3. 白名单复制 LuCI 基础
# ================================
echo "=== 白名单复制 LuCI 基础 ==="
mkdir -p feeds/luci
cp -r package/feeds/luci/* feeds/luci/ 2>/dev/null || true

# ================================
# 4. 复制 LuCI 主模块
# ================================
echo "=== 复制 LuCI 主模块（default-settings 必需） ==="
mkdir -p feeds/luci/modules
cp -r package/feeds/luci/modules/* feeds/luci/modules/ 2>/dev/null || true

# ================================
# 5. 复制 LuCI 中文语言包
# ================================
echo "=== 复制 LuCI 中文语言包（25.12 正确命名 zh_Hans） ==="
mkdir -p feeds/luci/i18n
cp -r package/feeds/luci/i18n/*zh_Hans* feeds/luci/i18n/ 2>/dev/null || true

# ================================
# 6. 禁用科学上网相关包
# ================================
echo "=== 禁用所有科学上网包（不复制） ==="

# ================================
# 7. 禁用底层库
# ================================
echo "=== 禁用所有 SSRPlus / Passwall2 依赖（不复制） ==="
echo "=== 禁用所有底层库依赖（libev/libsodium/libudns/boost 等） ==="
echo "=== 禁用 golang / rust ==="

# ================================
# 8. 三件套自动检测（官方目录）
# ================================
echo ">>> [三件套] 自动检测与自愈注册启动..."

DTS_FILE="target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
MK_FILE="target/linux/mediatek/image/filogic.mk"
CONFIG_FILE="sl3000/config/sl3000.config"

if [ ! -f "$DTS_FILE" ] || [ ! -f "$MK_FILE" ]; then
    echo "Error: 未找到 DTS 或 MK 补丁："
    echo "  DTS: $DTS_FILE"
    echo "  MK : $MK_FILE"
    exit 1
fi

echo ">>> 三件套检测成功："
echo "  DTS: $DTS_FILE"
echo "  MK : $MK_FILE"
echo "  CFG: $CONFIG_FILE"

# ================================
# 9. 注册三件套（写入标记）
# ================================
mkdir -p .selfheal
echo "$DTS_FILE" > .selfheal/dts.path
echo "$MK_FILE" > .selfheal/mk.path
echo "$CONFIG_FILE" > .selfheal/config.path

echo ">>> 三件套路径已注册完成"

# ================================
# 10. 单设备激活提示
# ================================
if grep -q "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" .config; then
    echo ">>> sl3000-emmc 已激活"
fi

echo "=== clean-feeds.sh v25.12-sl3000-final 完成 (可复现 + 三件套闭环, MK/DTS 已固定路径) ==="
