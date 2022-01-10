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

chmod a+x appimagetool-x86_64.AppImage
cp /neovim/build/bin/nvim /export/ -v
cp /neovim/build/opt /export/ -rv

ARCH=x86_64 ./appimagetool-x86_64.AppImage export/ nvim.appimage --comp gzip
