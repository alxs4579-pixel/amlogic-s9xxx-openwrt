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

# Prepare an overlay dir that gets merged into the rootfs
OVERLAY="${PWD}/files"
mkdir -p "${OVERLAY}"

# ---------------------------------------------------------------------------------
# Custom: install prebuilt (_all / arch-independent) ipk packages into the rootfs.
# Repos whose layout does not fit the OpenWrt feed model are pulled this way,
# because compiling them against LEDE's old LuCI fails.
# ---------------------------------------------------------------------------------
IPKDIR=/tmp/custom-ipk
rm -rf "${IPKDIR}" && mkdir -p "${IPKDIR}"

fetch_ipk() {
    # $1 = url, $2 = local filename
    if wget -q --no-check-certificate -T 60 -O "${IPKDIR}/$2" "$1"; then
        [ -s "${IPKDIR}/$2" ] && echo "OK   $2" && return 0
    fi
    rm -f "${IPKDIR}/$2"
    echo "FAIL $2"
    return 1
}

# --- Kucat theme + its config app (upstream uses ucode = LuCI 23.05+, unusable on LEDE)
fetch_ipk "https://github.com/sirpdboy/luci-theme-kucat/releases/download/v3.3.0/luci-theme-kucat_3.3.0-r20260227_all.ipk" "kucat.ipk"
fetch_ipk "https://github.com/sirpdboy/luci-app-kucat-config/releases/download/v2.2.0/luci-app-kucat-config_2.2.0-r20260227_all.ipk" "kucatcfg.ipk"
fetch_ipk "https://github.com/sirpdboy/luci-app-kucat-config/releases/download/v2.2.0/luci-i18n-kucat-config-zh-cn_0_all.ipk" "kucatcfg-zh.ipk"

# --- iStore app store (arch-independent pure-Lua packages from the public iStore repo)
fetch_ipk "https://istore.linkease.com/repo/all/nas_luci/luci-app-store_latest_all.ipk" "luci-app-store.ipk"

# ---------------------------------------------------------------------------------
# Unpack every ipk into the overlay (data.tar.gz only, no dependency resolution).
# ---------------------------------------------------------------------------------
for ipk in "${IPKDIR}"/*.ipk; do
    [ -f "$ipk" ] || continue
    work=/tmp/ipkx
    rm -rf "$work" && mkdir -p "$work"
    if tar -xzf "$ipk" -C "$work" 2>/dev/null && [ -f "$work/data.tar.gz" ]; then
        tar -xzf "$work/data.tar.gz" -C "${OVERLAY}" 2>/dev/null && echo "unpacked: $(basename "$ipk")" || echo "unpack-data FAILED: $(basename "$ipk")"
    else
        echo "unpack FAILED: $(basename "$ipk")"
    fi
done

# Keep LuCI config menu entries pointing at the kucat theme
mkdir -p "${OVERLAY}/etc/uci-defaults"
cat >"${OVERLAY}/etc/uci-defaults/99-custom-theme" <<'EOT'
#!/bin/sh
uci -q set luci.main.mediaurlbase='/luci-static/kucat'
uci -q commit luci
exit 0
EOT
chmod +x "${OVERLAY}/etc/uci-defaults/99-custom-theme"

# --- AdvancedPlus (advanced settings) ----------------------------------------------
# Repo root IS the package itself; clone directly into package/custom/.
rm -rf package/custom/luci-app-advancedplus
mkdir -p package/custom
git clone -b main --depth 1 https://github.com/sirpdboy/luci-app-advancedplus.git package/custom/luci-app-advancedplus 2>/dev/null \
    || echo "advancedplus: clone FAILED"

# --- OpenClash: drop the prebuilt cores (useless for armsr, keeps image small) ----
rm -rf feeds/openclash/luci-app-openclash/root/etc/openclash/core 2>/dev/null || true

# --- Make sure luci-compat is available (advancedplus depends on it) -------------
sed -i 's/# CONFIG_PACKAGE_luci-compat is not set/CONFIG_PACKAGE_luci-compat=y/g' .config 2>/dev/null || true
grep -q '^CONFIG_PACKAGE_luci-compat=y' .config || echo 'CONFIG_PACKAGE_luci-compat=y' >>.config

echo "=== overlay tree ==="
find "${OVERLAY}" -maxdepth 2 -type d 2>/dev/null | head -40
#
# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------