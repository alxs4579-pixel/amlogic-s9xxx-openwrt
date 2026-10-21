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
git clone -b main --depth 1 https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic

# ---------------------------------------------------------------------------------
# Custom: packages whose upstream repos do NOT have a standard feed layout.
# They must be cloned manually and placed where the build system can find them.
# ---------------------------------------------------------------------------------

# --- 1. iStore / iStoreOS app store -------------------------------------------------
# upstream layout:  luci/luci-app-store , luci/luci-lib-taskd , luci/luci-lib-xterm , luci/taskd
rm -rf /tmp/istore-src
git clone -b main --depth 1 https://github.com/linkease/istore.git /tmp/istore-src
mkdir -p package/custom
for p in luci-app-store luci-lib-taskd luci-lib-xterm taskd; do
    if [ -d "/tmp/istore-src/luci/$p" ]; then
        rm -rf "package/custom/$p"
        cp -r "/tmp/istore-src/luci/$p" "package/custom/$p"
        echo "istore: installed $p"
    else
        echo "istore: MISSING $p"
    fi
done

# --- 2. AdvancedPlus (advanced settings) --------------------------------------------
# upstream layout: repo ROOT is the package itself (.github doc luasrc po root)
rm -rf package/custom/luci-app-advancedplus
git clone -b main --depth 1 https://github.com/sirpdboy/luci-app-advancedplus.git package/custom/luci-app-advancedplus

# --- 3. quickstart / luci-app-linkease ----------------------------------------------
# From linkease/nas-packages (only multimedia + network at root; quickstart lives
# under network/services on some branches). Try to locate and copy if present.
rm -rf /tmp/nas-src
git clone -b master --depth 1 https://github.com/linkease/nas-packages.git /tmp/nas-src 2>/dev/null || true
if [ -d /tmp/nas-src ]; then
    found=""
    for cand in /tmp/nas-src/network/services/quickstart /tmp/nas-src/quickstart /tmp/nas-src/luci-app-quickstart; do
        if [ -d "$cand" ]; then found="$cand"; break; fi
    done
    if [ -n "$found" ]; then
        rm -rf package/custom/quickstart
        cp -r "$found" package/custom/quickstart
        echo "nas: installed quickstart from $found"
    else
        echo "nas: quickstart NOT FOUND - skipping"
    fi
    # ffmpeg-remux and other multimedia helpers
    for cand in /tmp/nas-src/multimedia/ffmpeg-remux; do
        if [ -d "$cand" ]; then
            cp -r "$cand" package/custom/ 2>/dev/null || true
        fi
    done
fi

# --- 4. OpenClash: drop the prebuilt cores (useless for armsr, keeps image small) ----
rm -rf feeds/openclash/luci-app-openclash/root/etc/openclash/core 2>/dev/null || true

# --- 5. Make sure luci-compat is available (advancedplus depends on it) -------------
sed -i 's/# CONFIG_PACKAGE_luci-compat is not set/CONFIG_PACKAGE_luci-compat=y/g' .config 2>/dev/null || true
grep -q '^CONFIG_PACKAGE_luci-compat=y' .config || echo 'CONFIG_PACKAGE_luci-compat=y' >>.config

echo "=== custom package tree ==="
ls -1 package/custom/ 2>/dev/null || true
#
# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------