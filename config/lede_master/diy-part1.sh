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
# Only feeds with a STANDARD root-level package layout are added here.
# Non-standard repos (nested dirs / ucode-based) are handled in diy-part2.sh as ipk.

# Argon theme (root-level luci-theme-argon)
echo 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' >>feeds.conf.default

# OpenClash (root-level luci-app-openclash)
echo 'src-git openclash https://github.com/vernesong/OpenClash.git;dev' >>feeds.conf.default
# ------------------------------- Custom feeds ended -------------------------------
