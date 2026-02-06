#!/bin/bash
set -e
# 接收传入的绝对路径
REPO_ROOT=$1
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000] 执行全量集成修复 (保留全部历史成果)..."

# 1. 物理注入镜像规则 (修正 cp 路径冲突)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
# 通过先进入目录再操作，物理规避 Same File 报错
(cd "${WORKDIR}/target/linux/mediatek/image" && cp -fv "${REPO_ROOT}/filogic.mk" ./filogic.mk)

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
# 修正 cp 报错：采用目录内相对操作
cp -fv "${REPO_ROOT}/sl3000.config" .config

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
