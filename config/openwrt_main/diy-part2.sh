#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: DIY script (After updating feeds — modify the default IP, hostname, theme, add/remove packages, etc.)
# Source code repository: https://github.com/openwrt/openwrt / Branch: main
#========================================================================================================================

# ------------------------------- Main source configuration -------------------------------
#
# Set the default LAN IP address
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
# Override default IP if a valid custom IP is provided as the first argument
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# Set the default password for the 'root' user (change empty password to 'password')
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# Append source repository information to etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEREPO='github.com/openwrt/openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='main'" >>package/base-files/files/etc/openwrt_release

# Configure ccache for build acceleration
# Remove existing ccache settings
sed -i '/CONFIG_DEVEL/d' .config
sed -i '/CONFIG_CCACHE/d' .config
# Apply new ccache configuration
if [[ "${2}" == "true" ]]; then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo "# CONFIG_CCACHE is not set" >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi
#
# ------------------------------- Main source configuration ends -------------------------------

# ------------------------------- Additional customizations -------------------------------
#
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
#
# Apply patches
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Additional customizations ends -------------------------------

# =============================== iStoreOS / Kucat customisation ===============================
#
OVERLAY="${PWD}/files"
mkdir -p "${OVERLAY}"

# Kucat becomes the default theme
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' ./feeds/luci/collections/luci/Makefile 2>/dev/null || true

# ---------- prebuilt ipk overlay ----------
# Only packages whose upstream source layout does not fit the feed model live here.
# Kucat itself is compiled from the "kucat" feed (upstream main has ucode LuCI).
IPKDIR=/tmp/custom-ipk
rm -rf "${IPKDIR}" && mkdir -p "${IPKDIR}"

fetch_ipk() {
    if wget -q --no-check-certificate -T 60 -O "${IPKDIR}/$2" "$1"; then
        [ -s "${IPKDIR}/$2" ] && echo "OK   $2" && return 0
    fi
    rm -f "${IPKDIR}/$2"
    echo "FAIL $2"
    return 1
}

# iStore store
fetch_ipk "https://istore.linkease.com/repo/all/store/luci-lib-xterm_4.18.0_all.ipk" "luci-lib-xterm.ipk"
fetch_ipk "https://istore.linkease.com/repo/all/store/taskd_1.0.3-2_all.ipk" "taskd.ipk"
fetch_ipk "https://istore.linkease.com/repo/all/store/luci-lib-taskd_1.0.26_all.ipk" "luci-lib-taskd.ipk"
fetch_ipk "https://istore.linkease.com/repo/all/store/luci-app-store_0.2.1-r1_all.ipk" "luci-app-store.ipk"

# iStoreOS-style homepage
fetch_ipk "https://istore.linkease.com/repo/all/nas_luci/luci-app-quickstart_0.12.10-r1_all.ipk" "luci-app-quickstart.ipk"
fetch_ipk "https://istore.linkease.com/repo/all/nas_luci/luci-i18n-quickstart-zh-cn_git-26.247.42887-c3af221_all.ipk" "quickstart-zh.ipk"
fetch_ipk "https://istore.linkease.com/repo/aarch64_cortex-a53/nas/quickstart_0.13.0-1_aarch64_cortex-a53.ipk" "quickstart-bin.ipk"

# kucat-config settings UI
fetch_ipk "https://github.com/sirpdboy/luci-app-kucat-config/releases/download/v2.2.0/luci-app-kucat-config_2.2.0-r20260227_all.ipk" "kucatcfg.ipk"
fetch_ipk "https://github.com/sirpdboy/luci-app-kucat-config/releases/download/v2.2.0/luci-i18n-kucat-config-zh-cn_0_all.ipk" "kucatcfg-zh.ipk"

# ---------- unpack into overlay ----------
for ipk in "${IPKDIR}"/*.ipk; do
    [ -f "$ipk" ] || continue
    work=/tmp/ipkx
    rm -rf "$work" && mkdir -p "$work"
    if tar -xzf "$ipk" -C "$work" 2>/dev/null && [ -f "$work/data.tar.gz" ]; then
        tar -xzf "$work/data.tar.gz" -C "${OVERLAY}" 2>/dev/null \
            && echo "unpacked: $(basename "$ipk")" \
            || echo "unpack-data FAILED: $(basename "$ipk")"
    else
        echo "unpack FAILED: $(basename "$ipk")"
    fi
done

# ---------- first-boot defaults ----------
mkdir -p "${OVERLAY}/etc/uci-defaults"
cat >"${OVERLAY}/etc/uci-defaults/99-custom-theme" <<'EOT'
#!/bin/sh
uci -q set luci.main.mediaurlbase='/luci-static/kucat'
uci -q commit luci
if command -v quickstart >/dev/null 2>&1; then
    echo "quickstart backend available"
else
    echo "quickstart backend missing - stock LuCI kept"
fi
exit 0
EOT
chmod +x "${OVERLAY}/etc/uci-defaults/99-custom-theme"

# ---------- advanced settings plugin ----------
rm -rf package/custom/luci-app-advancedplus
mkdir -p package/custom
git clone -b main --depth 1 https://github.com/sirpdboy/luci-app-advancedplus.git \
    package/custom/luci-app-advancedplus 2>/dev/null || echo "advancedplus: clone FAILED"

# ---------- OpenClash: drop prebuilt cores ----------
rm -rf feeds/openclash/luci-app-openclash/root/etc/openclash/core 2>/dev/null || true

# ---------- required deps ----------
grep -q '^CONFIG_PACKAGE_luci-compat=y' .config || echo 'CONFIG_PACKAGE_luci-compat=y' >>.config
echo 'CONFIG_PACKAGE_rpcd-mod-luci=y' >>.config

echo "=== overlay tree ==="
find "${OVERLAY}" -maxdepth 2 -type d 2>/dev/null | head -40
# =============================== end iStoreOS / Kucat customisation ===============================
