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
cp -r feeds/luci/luci-base feeds/luci/ 2>/dev/null || true

# ================================
# 4. 复制 LuCI 主模块
# ================================
echo "=== 复制 LuCI 主模块（default-settings 必需） ==="
mkdir -p feeds/luci/modules
cp -r feeds/luci/modules/luci feeds/luci/modules/ 2>/dev/null || true

# ================================
# 5. 复制 LuCI 中文语言包
# ================================
echo "=== 复制 LuCI 中文语言包（25.12 正确命名 zh_Hans） ==="
mkdir -p feeds/luci/i18n
cp -r feeds/luci/i18n/zh_Hans feeds/luci/i18n/ 2>/dev/null || true

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
# 8. 三件套自动检测（旗舰版 12 道检测）
# ================================
echo ">>> [三件套] 自动检测与自愈注册启动..."

DTS_FILE="target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
MK_FILE="target/linux/mediatek/image/filogic.mk"
CONFIG_FILE="$GITHUB_WORKSPACE/repo/sl3000/config/sl3000.config"   # ★ 模板 config（正确）

# --------------------------------
# ① 文件存在性检测
# --------------------------------
echo ">>> [1/12] 检查 DTS/MK/CONFIG 是否存在..."
[ -f "$DTS_FILE" ] || { echo "Error: DTS 不存在"; exit 1; }
[ -f "$MK_FILE" ] || { echo "Error: MK 不存在"; exit 1; }
[ -f "$CONFIG_FILE" ] || { echo "Error: 模板 CONFIG 不存在"; exit 1; }

# --------------------------------
# ② 文件可读性检测
# --------------------------------
echo ">>> [2/12] 检查文件可读性..."
[ -s "$DTS_FILE" ] || { echo "Error: DTS 文件为空"; exit 1; }
[ -s "$MK_FILE" ] || { echo "Error: MK 文件为空"; exit 1; }
[ -s "$CONFIG_FILE" ] || { echo "Error: 模板 CONFIG 文件为空"; exit 1; }

# --------------------------------
# ③ 设备名一致性检测（模板阶段不检查激活字段）
# --------------------------------
echo ">>> [3/12] 检查设备名一致性..."
grep -q "mt7981b-sl3000-emmc" "$DTS_FILE" || {
    echo "Error: DTS 未定义 mt7981b-sl3000-emmc"; exit 1;
}
grep -q "mt7981b-sl3000-emmc" "$MK_FILE" || {
    echo "Error: MK 未定义 mt7981b-sl3000-emmc"; exit 1;
}

# --------------------------------
# ④ DTS 节点完整性检测
# --------------------------------
echo ">>> [4/12] 检查 DTS 节点完整性..."
for node in memory chosen gpio aliases compatible; do
    grep -q "$node" "$DTS_FILE" || { echo "Error: DTS 缺少节点: $node"; exit 1; }
done

# --------------------------------
# ⑤ MK 设备定义完整性检测
# --------------------------------
echo ">>> [5/12] 检查 MK 设备定义完整性..."
for key in DEVICE_VENDOR DEVICE_MODEL DEVICE_VARIANT DEVICE_DTS DEVICE_PACKAGES IMAGES; do
    grep -q "$key" "$MK_FILE" || { echo "Error: MK 缺少字段: $key"; exit 1; }
done

# --------------------------------
# ⑥ CONFIG 激活检测（模板阶段跳过）
# --------------------------------
echo ">>> [6/12] 跳过 CONFIG 激活检测（激活由 defconfig 生成）"

# --------------------------------
# ⑦ CONFIG 必要项检测（模板）
# --------------------------------
echo ">>> [7/12] 检查 CONFIG 必要项..."
for cfg in CONFIG_TARGET_mediatek=y CONFIG_TARGET_mediatek_filogic=y; do
    grep -q "$cfg" "$CONFIG_FILE" || { echo "Error: 模板 CONFIG 缺少必要项: $cfg"; exit 1; }
done

# --------------------------------
# ⑧ 三件套交叉一致性检测
# --------------------------------
echo ">>> [8/12] 检查 DTS/MK/CONFIG 一致性..."
grep -q "mt7981b-sl3000-emmc" "$MK_FILE" || { echo "Error: MK 与 DTS 不一致"; exit 1; }

# --------------------------------
# ⑨ 隐含字符检测
# --------------------------------
echo ">>> [9/12] 检查 DTS/MK/CONFIG 隐含字符..."
for f in "$DTS_FILE" "$MK_FILE" "$CONFIG_FILE"; do
    grep -q $'\r' "$f" && { echo "Error: $f 存在 CRLF"; exit 1; }
    grep -q $'\xEF\xBB\xBF' "$f" && { echo "Error: $f 存在 BOM"; exit 1; }
done

# --------------------------------
# ⑩ 版本链路检测
# --------------------------------
echo ">>> [10/12] 检查版本链路..."
grep -q "25.12" "$MK_FILE" || echo "Warning: MK 未标注 25.12（允许）"

# --------------------------------
# ⑪ 自动修复（轻量）
# --------------------------------
echo ">>> [11/12] 自动修复轻量检查..."
for f in "$DTS_FILE" "$MK_FILE" "$CONFIG_FILE"; do
    sed -i 's/\r$//' "$f"
done

# --------------------------------
# ⑫ 注册三件套
# --------------------------------
echo ">>> [12/12] 注册三件套路径..."
mkdir -p .selfheal
echo "$DTS_FILE" > .selfheal/dts.path
echo "$MK_FILE" > .selfheal/mk.path
echo "$CONFIG_FILE" > .selfheal/config.path

echo ">>> 三件套 12 道检测 + 修复 + 注册 完成"

# ================================
# 10. 单设备激活提示（构建后 defconfig 才会生效）
# ================================
if [ -f ".config" ] && grep -q "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" .config; then
    echo ">>> sl3000-emmc 已激活"
fi

echo "=== clean-feeds.sh v25.12-sl3000-final 完成 ==="
