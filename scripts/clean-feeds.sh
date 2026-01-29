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
if [ -d feeds/helloworld/ssr-plus ]; then
  cp -r feeds/helloworld/ssr-plus $FEEDS_ROOT/helloworld/
elif [ -d feeds/small/ssr-plus ]; then
  cp -r feeds/small/ssr-plus $FEEDS_ROOT/small/
fi

# luci-app-ssr-plus
if [ -d feeds/helloworld/luci-app-ssr-plus ]; then
  cp -r feeds/helloworld/luci-app-ssr-plus $FEEDS_ROOT/helloworld/
elif [ -d feeds/small/luci-app-ssr-plus ]; then
  cp -r feeds/small/luci-app-ssr-plus $FEEDS_ROOT/small/
fi

# xray-core
if [ -d feeds/helloworld/xray-core ]; then
  cp -r feeds/helloworld/xray-core $FEEDS_ROOT/helloworld/
elif [ -d feeds/small/xray-core ]; then
  cp -r feeds/small/xray-core $FEEDS_ROOT/small/
fi

# v2ray-geodata
if [ -d feeds/helloworld/v2ray-geodata ]; then
  cp -r feeds/helloworld/v2ray-geodata $FEEDS_ROOT/helloworld/
elif [ -d feeds/small/v2ray-geodata ]; then
  cp -r feeds/small/v2ray-geodata $FEEDS_ROOT/small/
fi

# Passwall2
if [ -d feeds/small/luci-app-passwall2 ]; then
  cp -r feeds/small/luci-app-passwall2 $FEEDS_ROOT/small/
fi
if [ -d feeds/small/passwall2 ]; then
  cp -r feeds/small/passwall2 $FEEDS_ROOT/small/
fi

echo "=== 补齐 SSRPlus 依赖目录 ==="
SSR_DEPS=(
  dns2tcp microsocks tcping shadowsocksr-libev-ssr-check
  curl nping chinadns-ng dns2socks dns2socks-rust dnsproxy mosdns
  hysteria tuic-client shadow-tls ipt2socks kcptun-client naiveproxy
  redsocks2 shadowsocks-libev shadowsocksr-libev simple-obfs
  v2ray-plugin trojan lua-neturl coreutils coreutils-base64
)

for dep in "${SSR_DEPS[@]}"; do
  if [ -d "feeds/helloworld/$dep" ]; then
    cp -r "feeds/helloworld/$dep" "$FEEDS_ROOT/helloworld/"
  elif [ -d "feeds/packages/$dep" ]; then
    cp -r "feeds/packages/$dep" "$FEEDS_ROOT/packages/"
  elif [ -d "feeds/small/$dep" ]; then
    cp -r "feeds/small/$dep" "$FEEDS_ROOT/small/"
  fi
done

echo "=== 补齐底层库依赖 ==="
LIB_DEPS=(libev libsodium libudns boost boost-program_options boost-date_time)
for dep in "${LIB_DEPS[@]}"; do
  if [ -d "feeds/packages/$dep" ]; then
    cp -r "feeds/packages/$dep" "$FEEDS_ROOT/packages/"
  elif [ -d "feeds/helloworld/$dep" ]; then
    cp -r "feeds/helloworld/$dep" "$FEEDS_ROOT/helloworld/"
  fi
done

HOST_DEPS=(rust golang)
for dep in "${HOST_DEPS[@]}"; do
  if [ -d "feeds/packages/lang/$dep" ]; then
    mkdir -p "$FEEDS_ROOT/packages/lang"
    cp -r "feeds/packages/lang/$dep" "$FEEDS_ROOT/packages/lang/"
  fi
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
