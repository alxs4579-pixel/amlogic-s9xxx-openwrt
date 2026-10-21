#!/bin/bash
#===============================================================
# ImmortalWrt - custom feeds
#===============================================================

# Argon theme (src layout is standard)
sed -i '$a src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' feeds.conf.default

# OpenClash: branch "dev" keeps luci-app-openclash/ as a proper package dir
sed -i '$a src-git openclash https://github.com/vernesong/OpenClash.git;dev' feeds.conf.default

# Kucat theme: standard package layout on branch master, needs new ucode LuCI
# ImmortalWrt master ships ucode LuCI, so source build should work here.
sed -i '$a src-git kucat https://github.com/sirpdboy/luci-theme-kucat.git;master' feeds.conf.default

# helloworld: provides ssr-plus (ImmortalWrt does not bundle it)
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
