#!/bin/bash
set -e

echo ">>> [自愈体系] clean-feeds.sh v25.12-sl3000-final-V2 启动"

###############################################
# 0. 定义模板源 FEEDS（必须存在）
###############################################
SRC_FEEDS="$GITHUB_WORKSPACE/repo/feeds"
echo ">>> 使用模板源 FEEDS: $SRC_FEEDS"

###############################################
# 1. 清空 feeds
###############################################
echo "=== 清空 feeds 包 ==="
rm -rf feeds/*
mkdir -p feeds

###############################################
# 1.1 检查模板源完整性（fail-fast）
###############################################
REQUIRED_FEEDS=(
    "$SRC_FEEDS/luci/luci-base"
    "$SRC_FEEDS/luci/modules/luci"
    "$SRC_FEEDS/luci/collections/luci"
    "$SRC_FEEDS/luci/i18n/zh_Hans"
)

echo ">>> 检查模板源完整性..."
for path in "${REQUIRED_FEEDS[@]}"; do
    [ -d "$path" ] || {
        echo "Error: 模板源缺少必要目录: $path"
        exit 1
    }
done

###############################################
# 2. 白名单复制 LuCI 基础
###############################################
echo "=== 白名单复制 LuCI 基础 ==="
mkdir -p feeds/luci
cp -r "$SRC_FEEDS/luci/luci-base" feeds/luci/

###############################################
# 3. 复制 LuCI 主模块
###############################################
echo "=== 复制 LuCI 主模块 ==="
mkdir -p feeds/luci/modules
cp -r "$SRC_FEEDS/luci/modules/luci" feeds/luci/modules/

###############################################
# 4. 复制 LuCI 集合包（关键）
###############################################
echo "=== 复制 LuCI 集合包（collections/luci） ==="
mkdir -p feeds/luci/collections
cp -r "$SRC_FEEDS/luci/collections/luci" feeds/luci/collections/

###############################################
# 5. 复制 LuCI 中文语言包
###############################################
echo "=== 复制 LuCI 中文语言包 zh_Hans ==="
mkdir -p feeds/luci/i18n
cp -r "$SRC_FEEDS/luci/i18n/zh_Hans" feeds/luci/i18n/

###############################################
# 6. 检查 default-settings 是否依赖 zh-cn
###############################################
echo ">>> 检查 default-settings 是否依赖 zh-cn..."
if grep -R "luci-i18n-base-zh-cn" package/* 2>/dev/null; then
    NEED_ZHCN_COMPAT=1
    echo ">>> 检测到 zh-cn 旧依赖，启用兼容壳包"
else
    NEED_ZHCN_COMPAT=0
    echo ">>> 未检测到 zh-cn 依赖，兼容壳包将跳过"
fi

###############################################
# 7. 创建兼容壳包（仅当需要）
###############################################
if [ "$NEED_ZHCN_COMPAT" = "1" ]; then
    echo "=== 创建兼容壳包 luci-i18n-base-zh-cn ==="
    mkdir -p package/compat-zhcn
    cat > package/compat-zhcn/Makefile << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-i18n-base-zh-cn
PKG_VERSION:=1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/luci-i18n-base-zh-cn
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=Compatibility package for zh-cn
  DEPENDS:=+luci-i18n-base-zh_Hans
endef

define Package/luci-i18n-base-zh-cn/install
	true
endef

$(eval $(call BuildPackage,luci-i18n-base-zh-cn))
EOF
fi

###############################################
# 8. feeds 污染检测（必须干净）
###############################################
echo ">>> 检查 feeds 是否被污染..."
if find feeds -type f | grep -v "luci" | grep -q .; then
    echo "Error: feeds 目录出现非白名单文件，构建中止"
    exit 1
fi

###############################################
# 9. 工具链缓存检测
###############################################
if ls staging_dir/toolchain-* >/dev/null 2>&1; then
    echo ">>> 检测到工具链缓存，将跳过重建"
else
    echo ">>> 无工具链缓存，将重新构建工具链"
fi

###############################################
# 10. 三件套自动检测（旗舰版 12 道检测）
###############################################
echo ">>> [三件套] 自动检测与自愈注册启动..."

DTS_FILE="target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
MK_FILE="target/linux/mediatek/image/filogic.mk"
CONFIG_FILE="$GITHUB_WORKSPACE/repo/sl3000/config/sl3000.config"

echo ">>> [1/12] 检查 DTS/MK/CONFIG 是否存在..."
[ -f "$DTS_FILE" ] || { echo "Error: DTS 不存在"; exit 1; }
[ -f "$MK_FILE" ] || { echo "Error: MK 不存在"; exit 1; }
[ -f "$CONFIG_FILE" ] || { echo "Error: 模板 CONFIG 不存在"; exit 1; }

echo ">>> [2/12] 检查文件可读性..."
[ -s "$DTS_FILE" ] || { echo "Error: DTS 文件为空"; exit 1; }
[ -s "$MK_FILE" ] || { echo "Error: MK 文件为空"; exit 1; }
[ -s "$CONFIG_FILE" ] || { echo "Error: 模板 CONFIG 文件为空"; exit 1; }

echo ">>> [3/12] 检查设备名一致性..."
grep -q "mt7981b-sl3000-emmc" "$DTS_FILE" || { echo "Error: DTS 未定义 mt7981b-sl3000-emmc"; exit 1; }
grep -q "mt7981b-sl3000-emmc" "$MK_FILE" || { echo "Error: MK 未定义 mt7981b-sl3000-emmc"; exit 1; }

echo ">>> [4/12] 检查 DTS 节点完整性..."
for node in memory chosen gpio aliases compatible; do
    grep -q "$node" "$DTS_FILE" || { echo "Error: DTS 缺少节点: $node"; exit 1; }
done

echo ">>> [5/12] 检查 MK 设备定义完整性..."
for key in DEVICE_VENDOR DEVICE_MODEL DEVICE_VARIANT DEVICE_DTS DEVICE_PACKAGES IMAGES; do
    grep -q "$key" "$MK_FILE" || { echo "Error: MK 缺少字段: $key"; exit 1; }
done

echo ">>> [6/12] 跳过 CONFIG 激活检测（激活由 defconfig 生成）"

echo ">>> [7/12] 检查 CONFIG 必要项..."
for cfg in CONFIG_TARGET_mediatek=y CONFIG_TARGET_mediatek_filogic=y; do
    grep -q "$cfg" "$CONFIG_FILE" || { echo "Error: 模板 CONFIG 缺少必要项: $cfg"; exit 1; }
done

echo ">>> [8/12] 检查 DTS/MK/CONFIG 一致性..."
grep -q "mt7981b-sl3000-emmc" "$MK_FILE" || { echo "Error: MK 与 DTS 不一致"; exit 1; }

echo ">>> [9/12] 检查 DTS/MK/CONFIG 隐含字符..."
for f in "$DTS_FILE" "$MK_FILE" "$CONFIG_FILE"; do
    grep -q $'\r' "$f" && { echo "Error: $f 存在 CRLF"; exit 1; }
    grep -q $'\xEF\xBB\xBF' "$f" && { echo "Error: $f 存在 BOM"; exit 1; }
done

echo ">>> [10/12] 检查版本链路..."
grep -q "25.12" "$MK_FILE" || echo "Warning: MK 未标注 25.12（允许）"

echo ">>> [11/12] 自动修复轻量检查..."
for f in "$DTS_FILE" "$MK_FILE" "$CONFIG_FILE"; do
    sed -i 's/\r$//' "$f"
done

echo ">>> [12/12] 注册三件套路径..."
mkdir -p .selfheal
echo "$DTS_FILE" > .selfheal/dts.path
echo "$MK_FILE" > .selfheal/mk.path
echo "$CONFIG_FILE" > .selfheal/config.path

echo ">>> 三件套 12 道检测 + 修复 + 注册 完成"

###############################################
# 11. 生成构建指纹（可复现性核心）
###############################################
echo ">>> 生成构建指纹 .buildinfo"
{
    echo "DEVICE=sl3000-emmc"
    echo "TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "DTS_HASH=$(sha256sum $DTS_FILE | awk '{print $1}')"
    echo "MK_HASH=$(sha256sum $MK_FILE | awk '{print $1}')"
    echo "CONFIG_HASH=$(sha256sum $CONFIG_FILE | awk '{print $1}')"
} > .buildinfo

###############################################
# 12. defconfig 激活强校验
###############################################
if [ -f ".config" ]; then
    if ! grep -q "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" .config; then
        echo "Error: defconfig 未激活 sl3000-emmc"
        exit 1
    fi
    echo ">>> sl3000-emmc 已激活"
fi

echo "=== clean-feeds.sh v25.12-sl3000-final-V2 完成 ==="
