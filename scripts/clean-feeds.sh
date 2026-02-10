#!/bin/bash
set -eo pipefail

export TERM=xterm

# ==================== SL3000 eMMC 专属配置 ====================
cat > .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
CONFIG_DEVEL=y
CONFIG_BUSYBOX_CUSTOM=y
CONFIG_ATH11K_MEM_PROFILE_512M=y
# CONFIG_IB is not set
# CONFIG_SIGNATURE_CHECK is not set
EOF

# 关闭警告报错（99%失败都是因为它）
find . -name Makefile -type f -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -type f -exec sed -i 's/-Werror//g' {} +

# 标准 feeds 更新
./scripts/feeds update -a
./scripts/feeds install -a

# 生成最终配置
make defconfig
