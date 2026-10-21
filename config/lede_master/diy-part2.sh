#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (After Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

# ------------------------------- Main source started -------------------------------
#
# Set default IP address
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# Modify default theme (FROM luci-theme-bootstrap CHANGE TO luci-theme-kucat)
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' ./feeds/luci/collections/luci/Makefile 2>/dev/null || true

# Add autocore support for armsr-armv8
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armsr/g' package/lean/autocore/Makefile

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings
echo "DISTRIB_SOURCEREPO='github.com/coolsnowwolf/lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='master'" >>package/base-files/files/etc/openwrt_release
#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic

# Custom: OpenClash core cleanup (not needed for armsr, reduces image size)
rm -rf feeds/luci/applications/luci-app-openclash/root/etc/openclash/core 2>/dev/null || true
rm -rf feeds/openclash/luci-app-openclash/root/etc/openclash/core 2>/dev/null || true

# Custom: ensure luci-compat exists (advancedplus depends on it)
sed -i 's/# CONFIG_PACKAGE_luci-compat is not set/CONFIG_PACKAGE_luci-compat=y/g' .config 2>/dev/null || true

# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------