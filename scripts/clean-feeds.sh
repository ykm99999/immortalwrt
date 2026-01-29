#!/bin/bash
set -e

FEEDS_ROOT="package/feeds"

echo "=== 清空 feeds 包 ==="
rm -rf $FEEDS_ROOT/packages/*
rm -rf $FEEDS_ROOT/luci/*
rm -rf $FEEDS_ROOT/small/*
rm -rf $FEEDS_ROOT/helloworld/*

mkdir -p $FEEDS_ROOT/packages
mkdir -p $FEEDS_ROOT/luci
mkdir -p $FEEDS_ROOT/small
mkdir -p $FEEDS_ROOT/helloworld

echo "=== 保留 LuCI 基础 ==="
cp -r feeds/luci/modules/luci-base            $FEEDS_ROOT/luci/ || true
cp -r feeds/luci/modules/luci-compat          $FEEDS_ROOT/luci/ || true
cp -r feeds/luci/modules/luci-lua-runtime     $FEEDS_ROOT/luci/ || true
cp -r feeds/luci/libs/luci-lib-ip             $FEEDS_ROOT/luci/ || true
cp -r feeds/luci/libs/luci-lib-jsonc          $FEEDS_ROOT/luci/ || true
cp -r feeds/luci/themes/luci-theme-bootstrap  $FEEDS_ROOT/luci/ || true

echo "=== 保留 Passwall2 / SSRPlus / Xray ==="

# SSRPlus 主体
for path in feeds/helloworld/ssr-plus feeds/small/ssr-plus; do
  [ -d "$path" ] && cp -r "$path" "$FEEDS_ROOT/helloworld/" && break
done

# luci-app-ssr-plus
for path in feeds/helloworld/luci-app-ssr-plus feeds/small/luci-app-ssr-plus; do
  [ -d "$path" ] && cp -r "$path" "$FEEDS_ROOT/helloworld/" && break
done

# xray-core
for path in feeds/helloworld/xray-core feeds/small/xray-core; do
  [ -d "$path" ] && cp -r "$path" "$FEEDS_ROOT/helloworld/" && break
done

# v2ray-geodata
for path in feeds/helloworld/v2ray-geodata feeds/small/v2ray-geodata; do
  [ -d "$path" ] && cp -r "$path" "$FEEDS_ROOT/helloworld/" && break
done

# Passwall2
for path in feeds/small/luci-app-passwall2; do
  [ -d "$path" ] && cp -r "$path" "$FEEDS_ROOT/small/"
done
for path in feeds/small/passwall2; do
  [ -d "$path" ] && cp -r "$path" "$FEEDS_ROOT/small/"
done

echo "=== 补齐 SSRPlus 依赖目录（自动 fallback） ==="
SSR_DEPS=(
  dns2tcp microsocks tcping shadowsocksr-libev-ssr-check
  curl nping chinadns-ng dns2socks dns2socks-rust dnsproxy mosdns
  hysteria tuic-client shadow-tls ipt2socks kcptun-client naiveproxy
  redsocks2 shadowsocks-libev shadowsocksr-libev simple-obfs
  v2ray-plugin trojan lua-neturl coreutils coreutils-base64
)

for dep in "${SSR_DEPS[@]}"; do
  for path in feeds/helloworld/$dep feeds/packages/$dep feeds/small/$dep; do
    if [ -d "$path" ]; then
      cp -r "$path" "$FEEDS_ROOT/helloworld/" 2>/dev/null || \
      cp -r "$path" "$FEEDS_ROOT/packages/" 2>/dev/null || \
      cp -r "$path" "$FEEDS_ROOT/small/" 2>/dev/null
      break
    fi
  done
done

echo "=== 补齐底层库依赖（libev / libsodium / libudns / boost） ==="
LIB_DEPS=(libev libsodium libudns boost boost-program_options boost-date_time)

for dep in "${LIB_DEPS[@]}"; do
  for path in feeds/packages/$dep feeds/helloworld/$dep feeds/small/$dep; do
    if [ -d "$path" ]; then
      cp -r "$path" "$FEEDS_ROOT/packages/" 2>/dev/null || \
      cp -r "$path" "$FEEDS_ROOT/helloworld/" 2>/dev/null || \
      cp -r "$path" "$FEEDS_ROOT/small/" 2>/dev/null
      break
    fi
  done
done

echo "=== 补齐 host 依赖（golang/host / rust/host） ==="
HOST_DEPS=(golang rust)

for dep in "${HOST_DEPS[@]}"; do
  for path in feeds/packages/lang/$dep feeds/packages/$dep feeds/helloworld/$dep feeds/small/$dep; do
    if [ -d "$path" ]; then
      mkdir -p "$FEEDS_ROOT/packages/lang"
      cp -r "$path" "$FEEDS_ROOT/packages/lang/" 2>/dev/null || true
      break
    fi
  done
done

echo "=== 禁用主线包扫描 ==="
cat > .config << "EOF"
CONFIG_ALL=n
CONFIG_ALL_KMODS=n
CONFIG_ALL_NONSHARED=n
EOF

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
