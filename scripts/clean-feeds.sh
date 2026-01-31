#!/bin/bash
set -e

echo ">>> [自愈体系] clean-feeds.sh v25.12-sl3000 启动"

# ============================================================
# 0. 路径校验
# ============================================================
if [ ! -f "scripts/feeds" ]; then
    echo "[ERROR] 当前目录不是 OpenWrt 根目录: $(pwd)"
    exit 1
fi

FEEDS_ROOT="package/feeds"

# ============================================================
# 1. Feeds 白名单清理（25.12 新体系）
# ============================================================
echo "=== 清空 feeds 包 ==="
rm -rf $FEEDS_ROOT/packages/*
rm -rf $FEEDS_ROOT/luci/*
rm -rf $FEEDS_ROOT/small/*
rm -rf $FEEDS_ROOT/helloworld/*

mkdir -p $FEEDS_ROOT/packages
mkdir -p $FEEDS_ROOT/packages/libs
mkdir -p $FEEDS_ROOT/packages/lang
mkdir -p $FEEDS_ROOT/luci
mkdir -p $FEEDS_ROOT/small
mkdir -p $FEEDS_ROOT/helloworld

echo "=== 保留主树（不删除 package/system/* 等核心包） ==="
# 主树不再清空，避免破坏 apk/ubus/uci/procd/busybox 等构建链核心组件

copy_pkg() {
  local pkg="$1"
  for path in \
    feeds/helloworld/$pkg \
    feeds/small/$pkg \
    feeds/packages/$pkg \
    feeds/packages/libs/$pkg \
    feeds/packages/net/$pkg \
    feeds/packages/utils/$pkg \
    feeds/packages/lang/$pkg
  do
    if [ -d "$path" ]; then
      case "$path" in
        feeds/packages/libs/*)
          cp -r "$path" "$FEEDS_ROOT/packages/libs/"
          ;;
        feeds/packages/lang/*)
          cp -r "$path" "$FEEDS_ROOT/packages/lang/"
          ;;
        feeds/packages/*)
          cp -r "$path" "$FEEDS_ROOT/packages/"
          ;;
        feeds/small/*)
          cp -r "$path" "$FEEDS_ROOT/small/"
          ;;
        feeds/helloworld/*)
          cp -r "$path" "$FEEDS_ROOT/helloworld/"
          ;;
      esac
      return
    fi
  done
}

echo "=== 白名单复制 LuCI 基础 ==="
for p in \
  luci-base luci-compat luci-lua-runtime \
  luci-lib-ip luci-lib-jsonc luci-theme-bootstrap
do
  cp -r feeds/luci/**/$p $FEEDS_ROOT/luci/ 2>/dev/null || true
done

echo "=== 复制 LuCI 主模块（default-settings 必需） ==="
for p in \
  luci-mod-admin-full \
  luci-mod-network \
  luci-mod-status \
  luci-mod-system
do
  cp -r feeds/luci/**/$p $FEEDS_ROOT/luci/ 2>/dev/null || true
done

echo "=== 复制 LuCI 中文语言包（default-settings 必需） ==="
cp -r feeds/luci/**/luci-i18n-base-zh-cn $FEEDS_ROOT/luci/ 2>/dev/null || true

echo "=== 禁用所有科学上网包（不复制） ==="
# 故意留空

echo "=== 禁用所有 SSRPlus / Passwall2 依赖（不复制） ==="
# 故意留空

echo "=== 禁用所有底层库依赖（libev/libsodium/libudns/boost 等） ==="
# 故意留空

echo "=== 禁用 golang / rust ==="
# 故意留空

# ============================================================
# 2. 三件套自动检测 + 自愈注册（DTS / MK 闭环）
# ============================================================
echo ">>> [三件套] 自动检测与自愈注册启动..."

REPO_DIR="${GITHUB_WORKSPACE:-$(pwd)}/repo"

# 自动定位 DTS / MK
DTS_PATH=$(find "$REPO_DIR" -maxdepth 6 -name "mt7981b-sl3000-emmc.dts" | head -n 1)
MK_PATCH=$(find "$REPO_DIR" -maxdepth 6 -name "filogic-sl3000.mk" | head -n 1)

if [ -z "$DTS_PATH" ] || [ -z "$MK_PATCH" ]; then
    echo "[ERROR] 未找到 DTS 或 MK 补丁："
    echo "  DTS: $DTS_PATH"
    echo "  MK : $MK_PATCH"
    exit 1
fi

echo ">>> 三件套路径："
echo "  DTS : $DTS_PATH"
echo "  MK  : $MK_PATCH"

echo ">>> 三件套一致性检查..."

grep -q "mediatek,mt7981" "$DTS_PATH" \
  || { echo "[ERROR] DTS SoC 不匹配 (缺少 mediatek,mt7981)"; exit 1; }

grep -q "sl,sl3000-emmc" "$DTS_PATH" \
  || { echo "[ERROR] DTS compatible 不匹配 (缺少 sl,sl3000-emmc)"; exit 1; }

grep -q "sl_3000-emmc" "$MK_PATCH" \
  || { echo "[ERROR] MK 设备名不匹配 (缺少 sl_3000-emmc)"; exit 1; }

echo ">>> 三件套 Hash："
sha256sum "$DTS_PATH" "$MK_PATCH" || true

# --- 2.1 DTS 注入 ---
echo ">>> 注入 DTS 至 target/linux/mediatek/dts ..."
mkdir -p target/linux/mediatek/dts
rm -f target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts
cp -v "$DTS_PATH" target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts

# --- 2.2 MK 安全插入 ---
echo ">>> 安全插入 MK 设备定义 ..."
MK_TARGET="target/linux/mediatek/image/filogic.mk"

# 删除旧定义（幂等自愈）
sed -i '/Device\/sl_3000-emmc/,/endef/d' "$MK_TARGET"
sed -i '/TARGET_DEVICES += sl_3000-emmc/d' "$MK_TARGET"

# 结构化插入（保持原有结构，追加在最后一个 Device 后）
awk -v patch="$MK_PATCH" '
  BEGIN { inserted=0 }
  /^define Device/ { last=NR }
  { lines[NR]=$0 }
  END {
    for (i=1;i<=NR;i++) {
      print lines[i]
      if (i==last && !inserted) {
        while ((getline line < patch) > 0) print line
        inserted=1
      }
    }
  }
' "$MK_TARGET" > "$MK_TARGET.tmp"
mv "$MK_TARGET.tmp" "$MK_TARGET"

# ============================================================
# 3. 写入极简白名单 config（由 workflow 外层 make defconfig 展开）
# ============================================================
echo "=== 禁用主线包扫描 ==="
cat > .config << "EOF"
CONFIG_ALL=n
CONFIG_ALL_KMODS=n
CONFIG_ALL_NONSHARED=n
EOF

echo "=== 写入极简白名单 config（SL3000 eMMC 专用） ==="
cat >> .config << "EOF"
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_mt7981=y
CONFIG_TARGET_DEVICE_mediatek_mt7981_DEVICE_sl_3000-emmc=y

# 基础系统
CONFIG_PACKAGE_base-files=y
CONFIG_PACKAGE_busybox=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y
CONFIG_PACKAGE_ppp=y
CONFIG_PACKAGE_ppp-mod-pppoe=y
CONFIG_PACKAGE_coremark=y

# LuCI 基础
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lua-runtime=y
CONFIG_PACKAGE_luci-lib-ip=y
CONFIG_PACKAGE_luci-lib-jsonc=y
CONFIG_PACKAGE_luci-theme-bootstrap=y

# LuCI 网络管理
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-mod-system=y
CONFIG_PACKAGE_luci-proto-ppp=y
CONFIG_PACKAGE_luci-proto-ipv6=y

# 语言支持（仅保留基础）
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
EOF

# ============================================================
# 4. 完成
# ============================================================
echo "=== clean-feeds.sh 完成（白名单 + 三件套自动检测/自愈注册 + 工程体系延续） ==="
