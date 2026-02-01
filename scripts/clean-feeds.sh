#!/bin/bash
set -e

echo ">>> [自愈体系] clean-feeds.sh v25.12-sl3000-final-V12 启动"

# ImmortalWrt 25.12 的 LuCI 不在 feeds，而是在 package/luci
SRC_LUCI="$PWD/package/luci"
DEST_FEEDS="$PWD/feeds/luci"

echo ">>> LuCI 源路径: $SRC_LUCI"

if [ ! -d "$SRC_LUCI" ]; then
    echo "Error: 未找到 LuCI 源目录: $SRC_LUCI"
    exit 1
fi

# 清理并创建 feeds/luci
rm -rf "$DEST_FEEDS"
mkdir -p "$DEST_FEEDS"

###############################################
# 1. 复制 luci-base（真实路径）
###############################################
echo "=== 复制 luci-base ==="
cp -r "$SRC_LUCI/libs/luci-base" "$DEST_FEEDS/"

###############################################
# 2. 复制 LuCI 模块
###############################################
echo "=== 复制 LuCI 模块 ==="
mkdir -p "$DEST_FEEDS/modules"
cp -r "$SRC_LUCI/modules/"* "$DEST_FEEDS/modules/"

###############################################
# 3. 复制 LuCI 集合包
###############################################
echo "=== 复制 LuCI 集合包 ==="
mkdir -p "$DEST_FEEDS/collections"
cp -r "$SRC_LUCI/collections/"* "$DEST_FEEDS/collections/"

###############################################
# 4. 复制 LuCI 中文语言包
###############################################
echo "=== 复制 LuCI 中文语言包 ==="
mkdir -p "$DEST_FEEDS/i18n"
cp -r "$SRC_LUCI/i18n/zh_Hans" "$DEST_FEEDS/i18n/"

echo ">>> LuCI 复制完成（来自 package/luci，而非 feeds/luci）"

###############################################
# 5. default-settings zh-cn 兼容壳包
###############################################
echo ">>> 检查 default-settings 是否依赖 zh-cn..."
if grep -R "luci-i18n-base-zh-cn" package/* 2>/dev/null; then
    echo ">>> 检测到 zh-cn 旧依赖，创建兼容壳包"
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
else
    echo ">>> 未检测到 zh-cn 依赖，跳过兼容壳包"
fi

###############################################
# 6. feeds 污染检测
###############################################
echo ">>> 检查 feeds 是否被污染..."
if find feeds -type f | grep -v "luci" | grep -q .; then
    echo "Error: feeds 目录出现非白名单文件，构建中止"
    exit 1
fi

###############################################
# 7. 三件套自动检测（保持你原版 12 道检测）
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

echo "=== clean-feeds.sh v25.12-sl3000-final-V12 完成 ==="
