#!/bin/bash
set -e

echo ">>> [SL3000 全链路自愈] 正在处理编译障碍..."

TOPDIR=$(pwd)/openwrt
DTS_DEST_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"

# 1. 修复 Kconfig 循环依赖 (Zabbix vs PHP8)
# 原理：将 select (强制选中) 改为 depends on (软依赖)，打破死循环
echo ">>> [自愈] 修正 Zabbix/PHP8 循环依赖..."
cd "$TOPDIR"
if [ -d "feeds/packages/admin/zabbix" ]; then
    find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +
    echo "    - Zabbix 依赖已修正"
fi

# 2. 注入并修复 DTS 设备树
echo ">>> [自愈] 对齐 DTS 路径与 1GB 内存定义..."
mkdir -p "$DTS_DEST_DIR"
# 逻辑：同时修正头文件路径和内存寄存器定义
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    -e 's/reg = <0 0x40000000 0 0x20000000>;/reg = <0 0x40000000 0 0x40000000>;/g' \
    "../target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatekmt7981b-sl3000-emmc.d" \
    > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 3. 覆盖 Filogic 平台 Makefile
echo ">>> [自愈] 注入修复版 filogic.mk..."
cp -f "../target/linux/mediatek/image/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 4. 同步 Feeds 并注入 .config
echo ">>> [自愈] 正在同步 Feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

if [ -f "../sl3000/config/sl3000.config" ]; then
    cp -f "../sl3000/config/sl3000.config" ".config"
    # 额外补充 PHP 模块配置，防止 Zabbix 运行异常
    {
        echo "CONFIG_PACKAGE_php8=y"
        echo "CONFIG_PACKAGE_php8-mod-dom=y"
    } >> .config
fi

# 5. 执行最终校验
echo ">>> [自愈] 执行 make defconfig 校验逻辑..."
make defconfig

echo ">>> [成功] 所有编译障碍已清除，可以开始构建。"
