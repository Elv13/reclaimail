#!/bin/sh

cd neovim
mkdir -p build
cd build

cmake .. \
    -DCOMPILE_LUA=ON \
    -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
    -DLIBUV_LIBRARY=/libuv/build/libuv_a.a -DLIBUV_INCLUDE_DIR=/libuv/include/ \
    -DMSGPACK_LIBRARY=/msgpack-c/build/libmsgpackc.a -DMSGPACK_INCLUDE_DIR=/opt/lto-toolchain/$ARCH-linux-musl/include/ \
    -DLIBLUV_LIBRARY=/luv/build/libluv_a.a -DLIBLUV_INCLUDE_DIR=/luv/src/ \
    -DLUAJIT_LIBRARY=/LuaJIT/src/libluajit.a -DLUAJIT_INCLUDE_DIR=/LuaJIT/src \
    -DUNIBILIUM_LIBRARY=/unibilium/build/libunibilium.a -DUNIBILIUM_INCLUDE_DIR=/unibilium/ \
    -DLIBTERMKEY_LIBRARY=/libtermkey/.libs/libtermkey.a -DLIBTERMKEY_INCLUDE_DIR=/libtermkey/ \
    -DLIBVTERM_LIBRARY=/libvterm/.libs/libvterm.a -DLIBVTERM_INCLUDE_DIR=/libvterm/ \
    -DLibIntl_INCLUDE_DIR=/opt/lto-toolchain/$ARCH-linux-musl/include -DLibIntl_LIBRARY=/libuv/build/libuv_a.a \
    -DLUA_PRG=/LuaJIT/src/luajit -DCMAKE_INSTALL_PREFIX=/opt/neovim-static -DCMAKE_SYSROOT=$PREFIX

make -j16 install || exit $?

strip /opt/neovim-static/bin/* \
    -S \
    --strip-unneeded \
    --remove-section=.note.gnu.gold-version \
    --remove-section=.comment \
    --remove-section=.note \
    --remove-section=.note.gnu.build-id \
    --remove-section=.note.ABI-tag

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
    /opt/neovim-static/etc/nvim/lua/.git

# If your config rely on a theme, then install it.
for file in $(find /opt/neovim-static/share/nvim/runtime/colors/ -type f| grep -v elflord); do
    rm $file
done

# Delete some syntax highlight which few will miss
# (and sorry for being opiniated, blame `du -h`)
rm /opt/neovim-static/share/nvim/runtime/syntax/xs.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/hollywood.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/pfmain.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/baan.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/postscr.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/sas.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/nsis.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/foxpro.vim
rm /opt/neovim-static/share/nvim/runtime/syntax/autoit.vim

rm /opt/neovim-static/share/nvim/runtime/autoload/phpcomplete.vim \
    /opt/neovim-static/share/nvim/runtime/syntax/php.vim \
    /opt/neovim-static/share/nvim/runtime/autoload/haskellcomplete.vim \
    /opt/neovim-static/share/nvim/runtime/syntax/xmodmap.vim \
    /opt/neovim-static/share/nvim/runtime/syntax/sqlanywhere.vim \
    /opt/neovim-static/share/nvim/runtime/synmenu.vim \
    /opt/neovim-static/share/nvim/runtime/syntax/8th.vim

cd /
mkdir -p /export

# Compile the Lua config to bytecode
for file in $(find /opt/neovim-static/etc/ -iname '*.lua'); do
    mv $file ${file}.origin
    luajit -b ${file}.origin $file
    rm ${file}.origin
done

# Remove the comments from the .vim
for file in $(find /opt/neovim-static/ -iname '*.vim'); do
    mv $file ${file}.origin
    grep -vE '^[ ]*["]' ${file}.origin > $file
    rm ${file}.origin
done

ARCH=$ARCH appimagetool /opt/neovim-static/ /export/nvim.appimage --comp gzip
