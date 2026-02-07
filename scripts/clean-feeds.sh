#!/bin/bash
set -e

# ✅ 路径死锁：三件套在根目录，脚本在 scripts/
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "💎 [SL3000] 启动 25.12 补丁注入 (全量修复延续版)..."

cd "${WORKDIR}"

# 1. 延续修复：清理旧配置
rm -rf tmp .config .config.old

# 2. 延续修复：更新 Feeds
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心修复：强力锁定架构与设备
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 4. 载入自定义配置 (✅ 修正路径：从根目录读取 sl3000.config)
if [ -f "${SRC_DIR}/sl3000.config" ]; then
    cat "${SRC_DIR}/sl3000.config" >> .config
fi

# 5. 注入镜像定义 (✅ 修正路径：从根目录读取 filogic.mk)
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 6. 工具链劫持 (延续修复，解决 bison/m4 兼容性)
mkdir -p "staging_dir/host/bin"
ln -sf "$(which m4)" "staging_dir/host/bin/m4"
ln -sf "$(which flex)" "staging_dir/host/bin/flex"
ln -sf "$(which bison)" "staging_dir/host/bin/bison"
touch "staging_dir/host/.tools_install_y"

# 7. 生成配置
make defconfig

# 🎯 8. 延续成功案例：强制 512MB 限制，防止打包溢出
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ 补丁注入完成。"
