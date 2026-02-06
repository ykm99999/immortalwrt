#!/bin/bash
set -e
# 获取传入的绝对路径作为根目录，兜底使用当前目录
REPO_ROOT=${1:-$(pwd)}
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000] 执行全量数字化集成修复 (根目录: $REPO_ROOT)"

# 1. 物理劫持工具链 (解决编译环境报错)
mkdir -p "${WORKDIR}/staging_dir/host/bin"
for tool in m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    [ -n "$SYS_PATH" ] && ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool"
done

# 2. 物理注入 filogic.mk (必须包含 KERNEL_SIZE := 131072k)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
[ -f "${REPO_ROOT}/filogic.mk" ] && cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 3. 深度清理病灶包 (解决 24.10 依赖警告)
cd "${WORKDIR}"
./scripts/feeds update -a
rm -rf feeds/packages/lang/php* feeds/packages/admin/zabbix
rm -rf feeds/packages/net/hs20 feeds/packages/net/onionshare-cli
rm -rf feeds/luci/applications/luci-app-advanced-reboot
./scripts/feeds install -a

# 4. [数字化对齐] 强行锁定 128M/1024M 分区
if [ -f "${REPO_ROOT}/sl3000_defconfig" ]; then
    cp -fv "${REPO_ROOT}/sl3000_defconfig" .config
else
    echo "❌ 脚本无法找到配置文件: ${REPO_ROOT}/sl3000_defconfig"
    exit 1
fi

# 移除旧分区定义，强制写入数字化 MB 单位
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_CCACHE=y"
} >> .config

yes "" | make oldconfig
make defconfig
