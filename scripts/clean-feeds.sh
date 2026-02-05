#!/bin/bash
set -e
REPO_ROOT=$(pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000-Digital] 执行全量集成修复与僵尸依赖切除..."

# 1. 物理注入镜像规则 (数字化单位)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. [延续修复] 环境工具暴力劫持 (解决 Prerequisite)
mkdir -p "${WORKDIR}/staging_dir/host/bin" "${WORKDIR}/staging_dir/host/stamp"
for tool in m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    [ -n "$SYS_PATH" ] && ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool" && touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
done

# 3. [核心清理] 解决你日志中的 Dependency Warnings
cd "${WORKDIR}"
./scripts/feeds update -a

# 物理删除导致 Makefile 报错的病灶包
rm -rf feeds/packages/lang/php*
rm -rf feeds/packages/admin/zabbix
rm -rf feeds/packages/net/hs20
rm -rf feeds/packages/net/onionshare-cli
rm -rf feeds/luci/applications/luci-app-advanced-reboot

./scripts/feeds install -a

# 4. [数字化对齐] .config 强行锁定
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    # 配置使用数字 (MB)
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=64"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
} >> .config

yes "" | make oldconfig
make defconfig
