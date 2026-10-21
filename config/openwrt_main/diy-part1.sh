#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: DIY script (Before updating feeds — modify the default IP, hostname, theme, add/remove packages, etc.)
# Source code repository: https://github.com/openwrt/openwrt / Branch: main
#========================================================================================================================

# Add a custom feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default

# Argon theme (standard src layout)
sed -i '$a src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' feeds.conf.default

# OpenClash: branch "dev" keeps luci-app-openclash/ as a proper package dir
sed -i '$a src-git openclash https://github.com/vernesong/OpenClash.git;dev' feeds.conf.default

# Kucat theme: needs ucode LuCI; upstream main provides it
sed -i '$a src-git kucat https://github.com/sirpdboy/luci-theme-kucat.git;master' feeds.conf.default

# helloworld: provides ssr-plus (upstream OpenWrt does not bundle it)
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default

# Remove unnecessary packages
# rm -rf package/utils/{ucode,fbtest}
