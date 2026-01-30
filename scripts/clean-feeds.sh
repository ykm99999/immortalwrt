#!/bin/bash
set -e

FEEDS_ROOT="package/feeds"

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

# -------------------------------
# 自动 fallback 复制函数（增强版）
# -------------------------------
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
      # 复制到正确的 feeds 目录结构
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

# -------------------------------
# 1. LuCI 基础
# -------------------------------
echo "=== 保留 LuCI 基础 ==="
for p in \
  luci-base luci-compat luci-lua-runtime \
  luci-lib-ip luci-lib-jsonc luci-theme-bootstrap
do
  cp -r feeds/luci/**/$p $FEEDS_ROOT/luci/ 2>/dev/null || true
done

# -------------------------------
# 2. SSRPlus / Passwall2 / Xray
# -------------------------------
echo "=== 保留 Passwall2 / SSRPlus / Xray ==="
copy_pkg ssr-plus
copy_pkg luci-app-ssr-plus
copy_pkg xray-core
copy_pkg v2ray-geodata
copy_pkg luci-app-passwall2
copy_pkg passwall2

# -------------------------------
# 3. SSRPlus 依赖补齐
# -------------------------------
echo "=== 补齐 SSRPlus 依赖 ==="
SSR_DEPS=(
  dns2tcp microsocks tcping shadowsocksr-libev-ssr-check
  curl nping chinadns-ng dns2socks dns2socks-rust dnsproxy mosdns
  hysteria tuic-client shadow-tls ipt2socks kcptun-client naiveproxy
  redsocks2 shadowsocks-libev shadowsocksr-libev simple-obfs
  v2ray-plugin trojan lua-neturl coreutils coreutils-base64
)
for dep in "${SSR_DEPS[@]}"; do
  copy_pkg "$dep"
done

# -------------------------------
# 4. 底层库依赖补齐（关键修复）
# -------------------------------
echo "=== 补齐底层库依赖 ==="
LIB_DEPS=(libev libsodium libudns boost boost-program_options boost-date_time)
for dep in "${LIB_DEPS[@]}"; do
  copy_pkg "$dep"
done

# -------------------------------
# 5. host 工具依赖补齐（关键修复）
# -------------------------------
echo "=== 补齐 host 工具依赖（golang/host / rust/host） ==="
copy_pkg golang
copy_pkg rust

# -------------------------------
# 6. 禁用主线扫描
# -------------------------------
echo "=== 禁用主线包扫描 ==="
cat > .config << "EOF"
CONFIG_ALL=n
CONFIG_ALL_KMODS=n
CONFIG_ALL_NONSHARED=n
EOF

# -------------------------------
# 7. 写入白名单 config（25.12）
# -------------------------------
echo "=== 写入白名单 config（25.12 修复版） ==="
cat >> .config << "EOF"
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_mt7981=y
CONFIG_TARGET_DEVICE_mediatek_mt7981_DEVICE_sl_3000_emmc=y

CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lua-runtime=y
CONFIG_PACKAGE_luci-lib-ip=y
CONFIG_PACKAGE_luci-lib-jsonc=y
CONFIG_PACKAGE_luci-theme-bootstrap=y

CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-mod-system=y

CONFIG_PACKAGE_luci-app-passwall2=y
CONFIG_PACKAGE_passwall2=y

CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_ssr-plus=y

CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_v2ray-geodata=y

CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn=y
CONFIG_PACKAGE_luci-i18n-passwall2-zh-cn=y
EOF

echo "=== 白名单模式完成（25.12 完整修复版） ==="
