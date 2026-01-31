#!/bin/bash
set -e

echo ">>> [自愈体系] clean-feeds.sh v25.12-sl3000 启动"

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
echo "=== 复制 LuCI 中文语言包（default-settings 必需） ==="
mkdir -p feeds/luci/i18n
cp -r package/feeds/luci/i18n/*zh-cn* feeds/luci/i18n/ 2>/dev/null || true

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
# 8. 三件套自动检测
# ================================
echo ">>> [三件套] 自动检测与自愈注册启动..."

DTS_FILE=$(find "$GITHUB_WORKSPACE/sl3000/dts" -name "*.dts" | head -n 1)
MK_FILE=$(find "$GITHUB_WORKSPACE/sl3000/mk" -name "*.mk" | head -n 1)
CONFIG_FILE=$(find "$GITHUB_WORKSPACE/sl3000/config" -name "*.config" | head -n 1)

if [ ! -f "$DTS_FILE" ] || [ ! -f "$MK_FILE" ]; then
    echo "Error:  未找到 DTS 或 MK 补丁："
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
echo ">>> clean-feeds.sh 执行完毕"
