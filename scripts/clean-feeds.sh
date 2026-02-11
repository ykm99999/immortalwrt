#!/bin/bash
set -eo pipefail

# 强制定位到 openwrt 目录
cd "$(dirname "$0")/../openwrt" || exit 1

echo "=== 清理 feeds 缓存 ==="
rm -rf tmp feeds package/feeds

echo "=== 更新 feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

echo "=== 写入 .config ==="
cat > .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=512
CONFIG_PACKAGE_kmod-mmc=y
CONFIG_PACKAGE_kmod-sdhci-mtk=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_kmod-zram=y
CONFIG_PACKAGE_zram-swap=y
# CONFIG_TARGET_ROOTFS_INITRAMFS is not set
CONFIG_TARGET_ROOTFS_SQUASHFS=y
EOF

echo "=== 关闭编译警告报错 ==="
find . -name Makefile -type f -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -type f -exec sed -i 's/-Werror//g' {} +

echo "=== 生效配置 ==="
make defconfig

echo -e "\n✅ 配置完成，准备编译！"
