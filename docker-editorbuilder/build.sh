#!/bin/sh

cd neovim
mkdir -p build
cd build

cmake .. \
    -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
    -DLIBUV_LIBRARY=/libuv/build/libuv_a.a -DLIBUV_INCLUDE_DIR=/libuv/include/ \
    -DMSGPACK_LIBRARY=/msgpack-c/build/libmsgpackc.a -DMSGPACK_INCLUDE_DIR=/opt/lto-toolchain/x86_64-linux-musl/include/ \
    -DLIBLUV_LIBRARY=/luv/build/libluv_a.a -DLIBLUV_INCLUDE_DIR=/luv/src/ \
    -DLUAJIT_LIBRARY=/LuaJIT/src/libluajit.a -DLUAJIT_INCLUDE_DIR=/LuaJIT/src \
    -DUNIBILIUM_LIBRARY=/unibilium/build/libunibilium.a -DUNIBILIUM_INCLUDE_DIR=/unibilium/ \
    -DLIBTERMKEY_LIBRARY=/libtermkey/.libs/libtermkey.a -DLIBTERMKEY_INCLUDE_DIR=/libtermkey/ \
    -DLIBVTERM_LIBRARY=/libvterm/.libs/libvterm.a -DLIBVTERM_INCLUDE_DIR=/libvterm/ \
    -DLibIntl_INCLUDE_DIR=/opt/lto-toolchain/x86_64-linux-musl/include -DLibIntl_LIBRARY=/libuv/build/libuv_a.a \
    -DLUA_PRG=/LuaJIT/src/luajit -DCMAKE_INSTALL_PREFIX=/opt/neovim-static -DCMAKE_SYSROOT=$PREFIX

make -j16 install || exit $?

# Cleanup unused assets
rm -r /opt/neovim-static/share/locale/ \
    /opt/neovim-static/share/man \
    /opt/neovim-static/share/nvim/runtime/ftplugin \
    /opt/neovim-static/share/nvim/runtime/lua \
    /opt/neovim-static/share/nvim/runtime/tutor \
    /opt/neovim-static/share/applications \
    /opt/neovim-static/lib \
    /opt/neovim-static/share/nvim/runtime/doc \
    /opt/neovim-static/share/nvim/runtime/pack/dist/opt/*/doc \
    /opt/neovim-static/share/icons/ \
    /opt/neovim-static/config/.git

# If your config rely on a theme, then install it.
for file in $(find /opt/neovim-static/share/nvim/runtime/colors/ | grep -v elflord); do
    rm $file
done

cd /
mkdir -p /export

ARCH=x86_64 appimagetool /opt/neovim-static/ /export/nvim.appimage --comp gzip
