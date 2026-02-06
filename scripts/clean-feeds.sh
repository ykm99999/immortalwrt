#!/bin/bash
set -e
REPO_ROOT=$1
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000] 执行全量集成修复 (保留之前所有修复)..."

# 1. 注入镜像规则 (修正 cp 报错点)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv -f "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. [延续修复] 环境工具劫持
mkdir -p "${WORKDIR}/staging_dir/host/bin"
for tool in m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    [ -n "$SYS_PATH" ] && ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool"
done

# 3. [深度清理] 照抄原文清理逻辑
cd "${WORKDIR}"
./scripts/feeds update -a
rm -rf feeds/packages/lang/php* feeds/packages/admin/zabbix
rm -rf feeds/packages/net/hs20 feeds/packages/net/onionshare-cli
./scripts/feeds install -a

# 4. [数字化对齐] 配置注入与分区锁定 (128M/1024M)
cp -fv -f "${REPO_ROOT}/sl3000.config" .config

sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
} >> .config

# 严格激活配置
yes "" | make oldconfig
make defconfig
