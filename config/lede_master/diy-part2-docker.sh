#!/bin/bash
#========================================================================================================================
# Docker stack enabler for LEDE (runs AFTER `make defconfig`)
#
# Why this file exists:
#   The workflow order is:  cp config -> diy-part2.sh -> make defconfig -> make download
#   `make defconfig` strips any CONFIG_PACKAGE_* symbol that the enabled feeds do not
#   provide. Writing docker options inside diy-part2.sh is therefore useless: they are
#   removed two seconds later. This script is invoked right after `make defconfig`,
#   followed by a second `make defconfig` pass, so the options survive.
#
# Only enabled when the branch actually ships the docker packages in its feeds.
#========================================================================================================================

set -u

echo "=== docker-enable: start ==="
echo "PWD=$(pwd)"

# --- 1. make sure the docker packages exist in the feeds -------------------------
have_pkg() {
    # $1 = package name as used by `scripts/feeds list`
    ./scripts/feeds list 2>/dev/null | grep -qE "(^|[\/ ])$1\$"
}

MISSING=""
for p in dockerd docker containerd runc; do
    if ! have_pkg "$p"; then
        MISSING="${MISSING} $p"
    fi
done

if [ -n "${MISSING}" ]; then
    echo "docker-enable: SKIPPED, feeds do not provide:${MISSING}"
    echo "docker-enable: this branch ($(. /etc/os-release 2>/dev/null; echo unknown)) has no docker feed"
    exit 0
fi

# --- 2. hard requirements (engine + LuCI) ---------------------------------------
REQ="dockerd docker containerd runc luci-app-dockerman luci-lib-docker luci-i18n-dockerman-zh-cn tini"

# --- 3. optional, only enable when the feed actually has them -------------------
OPT="docker-compose libnetwork blkid block-mount blockd iptables iptables-mod-extra nftables-json jansson4 kmod-veth kmod-br-netfilter kmod-nf-nat kmod-ipt-ipset kmod-nf-ipvs kmod-ipt-physdev"

enable_pkg() {
    p="$1"
    sed -i "/^# CONFIG_PACKAGE_${p} is not set\$/d" .config
    sed -i "s/^CONFIG_PACKAGE_${p}=m\$/CONFIG_PACKAGE_${p}=y/" .config
    grep -q "^CONFIG_PACKAGE_${p}=y\$" .config || echo "CONFIG_PACKAGE_${p}=y" >>.config
}

for p in ${REQ}; do
    if have_pkg "$p"; then
        enable_pkg "$p"
        echo "docker-enable: ON  $p (required)"
    else
        echo "docker-enable: WARN required package missing from feeds: $p"
    fi
done

for p in ${OPT}; do
    if have_pkg "$p"; then
        enable_pkg "$p"
        echo "docker-enable: on  $p"
    fi
done

# --- 4. kernel bits ------------------------------------------------------------
for k in CONFIG_CGROUPS CONFIG_NAMESPACES CONFIG_NET_NS CONFIG_VETH CONFIG_BRIDGE_NETFILTER CONFIG_NF_NAT; do
    grep -q "^${k}=y\$" .config || echo "${k}=y" >>.config
done

echo "=== docker-enable: resulting .config entries ==="
grep -E "^CONFIG_PACKAGE_(docker|dockerd|containerd|runc|luci-app-dockerman|luci-lib-docker)=" .config || echo "(none)"

echo "=== docker-enable: done ==="
exit 0
