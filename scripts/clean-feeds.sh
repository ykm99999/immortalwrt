#!/bin/bash
set -e
REPO_ROOT=$(pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000 Flagship] 执行全量集成逻辑..."

# 1. 注入镜像规则 (继承)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. 环境劫持 (继承：解决 Prerequisite 报错)
mkdir -p "${WORKDIR}/staging_dir/host/bin" "${WORKDIR}/staging_dir/host/stamp"
TOOLS="m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3"
for tool in $TOOLS; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    [ -n "$SYS_PATH" ] && ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool" && touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
done
ln -sf /usr/bin/getopt "${WORKDIR}/staging_dir/host/bin/getopt"

# 3. Feeds 处理 (继承：物理切除 PHP/Zabbix 递归依赖)
cd "${WORKDIR}"
./scripts/feeds update -a
rm -rf feeds/packages/lang/php8 feeds/packages/admin/zabbix
./scripts/feeds install -a

# 4. 配置锁死 (继承)
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_CCACHE=y"
} >> .config

# 静默接受所有配置确认
yes "" | make oldconfig
make defconfig
