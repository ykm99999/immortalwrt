name: SL3000-2512-Ultra-Final

on:
  workflow_dispatch:

env:
  WORKDIR: openwrt
  DEVICE_NAME: sl3000-emmc

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - name: 1. 检出仓库
        uses: actions/checkout@v4

      - name: 2. 磁盘环境调优 (12G Swap + 空间清理)
        run: |
          sudo rm -rf /usr/share/dotnet /opt/ghc /var/lib/docker /usr/local/lib/android || true
          sudo swapoff -a || true
          sudo fallocate -l 12G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
          sudo apt-get update
          sudo apt-get install -y build-essential flex bison m4 gawk rsync unzip wget python3 device-tree-compiler libncurses5-dev libssl-dev

      - name: 3. 克隆源码 (锁定 25.12 分支)
        run: git clone --depth=1 -b openwrt-25.12 https://github.com/immortalwrt/immortalwrt.git ${{ env.WORKDIR }}

      - name: 4. 开启状态缓存 (🎯 即使构建失败也保存)
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.WORKDIR }}/dl
            ${{ env.WORKDIR }}/staging_dir
          save-always: true
          key: ${{ runner.os }}-sl3000-2512-ultra-${{ github.run_id }}
          restore-keys: |
            ${{ runner.os }}-sl3000-2512-ultra-

      - name: 5. 运行脚本补丁 (资产搬运)
        run: chmod +x scripts/clean-feeds.sh && ./scripts/clean-feeds.sh

      - name: 6. 编译基础工具链
        working-directory: ${{ env.WORKDIR }}
        run: |
          make tools/install -j$(nproc)
          make tools/firmware-utils/compile V=s
          make toolchain/install -j$(nproc)

      - name: 7. DTS 完全体物理注入 (🎯 修复 No such file 报错)
        working-directory: ${{ env.WORKDIR }}
        run: |
          make target/linux/prepare -j$(nproc)
          # 找到内核 DTS 根目录
          DTS_BASE_PATH=$(find build_dir -path "*/arch/arm64/boot/dts" -type d | head -n 1)
          
          if [ -n "$DTS_BASE_PATH" ]; then
            echo "📥 正在物理注入双层 DTS 路径..."
            
            # 第一层：注入父目录 (解决 ImageBuilder 报错)
            cp -fv ../mt7981b-sl3000-emmc.dts "$DTS_BASE_PATH/"
            
            # 第二层：注入 mediatek 子目录 (用于内核 DTB 编译)
            mkdir -p "$DTS_BASE_PATH/mediatek"
            cp -fv ../mt7981b-sl3000-emmc.dts "$DTS_BASE_PATH/mediatek/"
            
            # 在子目录 Makefile 中注册
            sed -i '/mt7981b-sl3000-emmc.dtb/d' "$DTS_BASE_PATH/mediatek/Makefile"
            echo 'dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' >> "$DTS_BASE_PATH/mediatek/Makefile"
            
            echo "✅ DTS 注入完成，当前路径: $DTS_BASE_PATH"
          else
            echo "❌ 未找到 DTS 目录，请检查源码结构！"
            exit 1
          fi

      - name: 8. 极限封包编译 (🎯 Error 127 物理劫持 + 暴力通关)
        working-directory: ${{ env.WORKDIR }}
        run: |
          HOST_BIN="$(pwd)/staging_dir/host/bin"
          mkdir -p "$HOST_BIN"
          
          # 劫持关键工具
          [ ! -f "$HOST_BIN/opkg" ] && cp -fv "$(which opkg)" "$HOST_BIN/opkg" || true
          [ ! -f "$HOST_BIN/mkhash" ] && cp -fv "$(which mkhash)" "$HOST_BIN/mkhash" || true
          
          # 建立 fwtool 系统级别链接
          FW_REAL=$(find staging_dir/host/bin/ -name "fwtool" | head -n 1)
          [ -n "$FW_REAL" ] && sudo ln -sf "$(pwd)/$FW_REAL" /usr/bin/fwtool || true
          
          export PATH="$HOST_BIN:$PATH"
          
          # 执行编译，允许收尾阶段 manifest 报错 (|| true)
          make target/linux/compile -j$(nproc) V=s
          make target/linux/install -j$(nproc) DEVICE_${{ env.DEVICE_NAME }}=y || \
          make target/linux/install -j1 V=s DEVICE_${{ env.DEVICE_NAME }}=y

      - name: 9. 固件地毯式打捞 (🎯 抢救 .bin)
        working-directory: ${{ env.WORKDIR }}
        run: |
          FIRMWARE=$(find bin/targets/ -name "*sl3000*sysupgrade.bin" | head -n 1)
          if [ -n "$FIRMWARE" ]; then
            SIZE=$(stat -c%s "$FIRMWARE")
            echo "📏 固件生成成功，大小: $SIZE 字节"
            [ $SIZE -ge 134217728 ] && echo "✅ 匹配 128MB 逻辑" || echo "⚠️ 规格检测异常"
          else
            echo "❌ 固件打捞失败，编译未完成！"
            exit 1
          fi

      - name: 10. 发布 Release
        uses: softprops/action-gh-release@v2
        if: success()
        with:
          tag_name: SL3000-2512-Final-${{ github.run_id }}
          files: |
            ${{ env.WORKDIR }}/bin/targets/mediatek/filogic/*.bin
            ${{ env.WORKDIR }}/bin/targets/mediatek/filogic/*.manifest
          token: ${{ secrets.GITHUB_TOKEN }}
