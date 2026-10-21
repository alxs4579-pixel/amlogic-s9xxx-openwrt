#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default

# other
# rm -rf package/lean/{samba4,luci-app-samba4,luci-app-ttyd}

# ------------------------------- Custom feeds started -------------------------------
# iStoreOS style homepage + app store
echo 'src-git istore https://github.com/linkease/istore.git;main' >>feeds.conf.default
echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >>feeds.conf.default

# Themes
echo 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' >>feeds.conf.default
echo 'src-git kucat https://github.com/sirpdboy/luci-theme-kucat.git;main' >>feeds.conf.default

# OpenClash
echo 'src-git openclash https://github.com/vernesong/OpenClash.git;dev' >>feeds.conf.default

# Advanced settings (luci-app-advancedplus)
echo 'src-git advancedplus https://github.com/sirpdboy/luci-app-advancedplus.git;main' >>feeds.conf.default
# ------------------------------- Custom feeds ended -------------------------------
