#!/bin/bash
# ============================================================
# SL3000 V19.0 旗舰版：全路径硬关联 + Feeds 认证绕过
# ============================================================
set -e

echo ">>> [SL3000 V19.0] 启动工厂级物理注入..."

# --- 1. 资产路径校验 ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

[ ! -f "$DTS_SRC" ] && { echo "❌ 缺失 DTS: $DTS_SRC"; exit 1; }
[ ! -f "$MK_SRC" ] && { echo "❌ 缺失 MK: $MK_SRC"; exit 1; }
[ ! -f "$CONF_SRC" ] && { echo "❌ 缺失 Config: $CONF_SRC"; exit 1; }

# --- 2. DTS 注入与内核 Makefile 注册 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [自愈] 修正 DTS 引用并注册机型..."
tr -d '\r' < "$DTS_SRC" > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"
# 物理注册 DTB 到内核编译列表
K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# --- 3. 驱动补丁与 Makefile 注入 ---
echo ">>> [注入] 覆盖并加固驱动定义..."
# 在拷贝前先向源文件注入 eMMC 驱动补丁，确保生成的镜像包含驱动
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 配置合并与 Feeds 强力自愈 ---
echo ">>> [Feeds] 重构插件源，解决 Git 认证报错..."
cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 关键：移除可能导致认证错误的 Git 代替指令
git config --global --unset url."https://github.com/".insteadOf || true

# 重新生成 feeds.conf.default
sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

# 更新并安装，加入重试逻辑
for i in {1..3}; do
    ./scripts/feeds update -a && break || sleep 5
done
./scripts/feeds install -a

# 解决 Zabbix/PHP8 递归依赖
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

make defconfig
echo "✅ [任务完成] V19.0 注入与配置锁定成功！"
