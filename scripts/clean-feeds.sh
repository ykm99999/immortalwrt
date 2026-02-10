#!/bin/bash
set -eo pipefail

export TERM=xterm

cat > .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF

# 关闭警告报错
find . -name Makefile -type f -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -type f -exec sed -i 's/-Werror//g' {} +

./scripts/feeds update -a
./scripts/feeds install -a

make defconfig
