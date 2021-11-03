# This Dockerfile creates a very small AppImage using static
# linking and LTO. It is 100% portable for all x86_64 *OR*
# aarch64 systems.
#
# The general idea is to create a single file you can `scp`
# into all of your system and have a Lua based self contained
# config "just working".
#
# This Dockerfile goes out of its way to setup a proper
# cross compile toolchain for the sake of saving a kilobits...
# This also means ingnoring all the goodies of neovim build
# system because "I know better". Still, given how it's used
# and how the Reclaim project is hardened, it makes sense
# to share a static editor across the project.
FROM debian:buster-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

RUN apt update && apt install -y build-essential git cmake  \
    pkg-config libtool-bin wget curl gperf gettext texinfo

RUN git clone https://github.com/neovim/neovim.git;         \
    git clone https://github.com/libuv/libuv.git;           \
    git clone https://github.com/msgpack/msgpack-c.git;     \
    git clone https://github.com/luvit/luv.git;             \
    git clone https://github.com/LuaJIT/LuaJIT.git;         \
    git clone https://github.com/neovim/unibilium.git;      \
    git clone https://github.com/neovim/libtermkey.git;     \
    git clone https://github.com/neovim/libvterm.git;       \
    git clone https://github.com/luvit/lpeg.git;            \
    git clone https://github.com/libmpack/libmpack-lua.git; \
    git clone git://git.musl-libc.org/musl

# Compile binutils, just because we have a custom GCC...
RUN wget https://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.bz2 && \
    tar -xpvf binut*; cd binut*; ./configure --prefix=/opt/lto-toolchain \
    --target=x86_64-linux-musl --disable-multilib --disable-nls --enable-gold=yes\
    --disable-werror; make -j16 && make install; \
    cd /; rm -rf binut*

# Install Ancient Linux kernel headers. This will make sure we
# don't use systemcall newer than CentOS 6.0 (2010). This is
# the oldest system we can assume to work. Older RHEL were not
# super good at 64 bit anyway. If anyone still uses 10+ years
# old Ubuntu, they are insane. People with retro-computing
# are not on 64bit. So this kernel should work for everybody
# (using Linux).
RUN wget https://mirrors.edge.kernel.org/pub/linux/kernel/v2.6/linux-2.6.32.1.tar.bz2; \
    tar -xpvf linux-*; cd cd linux-2.6.32.1; \
    make ARCH=x86_64 INSTALL_HDR_PATH=/opt/lto-toolchain/x86_64-linux-musl headers_install; \
    cd /; rm -rf linux-2*

# Let's build GCC, everybody loves building custom GCCs, right?
# The real reason is to disable thread local storage. LuaJIT
# doesn't use pthread for portability, which means it is also
# pretty dumb because it doesn't re-implement all the safety
# logic pthread provides. If it wasn't for this issue, the
# `musl-tools` GCC config included in Debian would have worked.
RUN wget https://ftpmirror.gnu.org/gcc/gcc-9.1.0/gcc-9.1.0.tar.gz; \
    tar -xpvf gcc*; cd gcc*;contrib/download_prerequisites;\
    mkdir build-src;cd build-src;../configure --disable-tls --disable-multilib --enable-languages=c \
    --disable-libstdcxx  --disable-nls --disable-libgomp --disable-libitm     \
    --disable-libquadmath --disable-libsanitizer --disable-libssp             \
    --disable-libvtv --disable-libstdc__-v3 --enable-lto --enable-gold=yes    \
    --enable-ld=no --target=x86_64-linux-musl --host=x86_64-linux-gnu         \
    --disable-bootstrap --prefix=/opt/lto-toolchain && \
    make -j16 all-gcc && make install-gcc; rm -rf ./*

# We need a custom built musl for this, otherwise it will
# abort when LuaJIT tries to use too much stack. We also need
# to enable LTO. In my testing, 256kB never had issues, 128kB
# crashed a couple time. Note that it is important to set the
# variables for CC, CFLAGS and LD directly. We can't enable
# LTO yet and can't set the ENV because GCC in the next step
# still uses the host compiler.

RUN cd musl* && \
    sed -i 's/DEFAULT_STACK_SIZE 131072/DEFAULT_STACK_SIZE 262144/' src/internal/pthread_impl.h && \
    CFLAGS="-Os -fPIC" CC=/opt/lto-toolchain/bin/x86_64-linux-musl-gcc LD=/opt/lto-toolchain/bin/x86_64-linux-musl-ld \
    CROSS_COMPILE=/opt/lto-toolchain/ ./configure  --prefix=/opt/lto-toolchain/x86_64-linux-musl --disable-shared && \
    CFLAGS="-Os -fPIC" CC=/opt/lto-toolchain/bin/x86_64-linux-musl-gcc LD=/opt/lto-toolchain/bin/x86_64-linux-musl-ld \
    CROSS_COMPILE=/opt/lto-toolchain/ make AR=/opt/lto-toolchain/bin/x86_64-linux-musl-ar \
    RANLIB=/opt/lto-toolchain/bin/x86_64-linux-musl-ranlib && make install

# Back to GCC, finish the job: add C++, libgcc and libstdc++
# (msgpack *needs* it, but doesn't *use* it...). Note that GCC must
# be compiled in 2 steps to do a bootstrap because it needs the libc
# header and the libc header are slightly dependant on the compiler
# setup.
RUN cd /gcc*/build-src;../configure \
    --disable-tls --disable-multilib --enable-languages=c,c++            \
    --disable-bootstrap --disable-nls --disable-libssp --disable-libvtv  \
    --disable-libsanitizer --disable-libgomp --disable-libitm            \
    --enable-lto --enable-gold=yes --enable-ld=yes                       \
    --target=x86_64-linux-musl --host=x86_64-linux-gnu                   \
    --prefix=/opt/lto-toolchain && make -j16 && make install;rm -rf ./* 

#RUN cd /gcc*/build-src;rm -rf./*;../configure \
#    --disable-tls --disable-multilib --enable-languages=c,c++                 \
#    --disable-bootstrap --disable-nls --disable-libgomp --disable-libitm      \
#    --disable-libquadmath --disable-libsanitizer --disable-libssp             \
#    --disable-libvtv --enable-lto --enable-gold=yes --enable-ld=no            \
#    --target=x86_64-linux-musl --host=x86_64-linux-gnu                        \
#    --prefix=/opt/lto-toolchain && make -j16; make install

# Nothing special here, we are targetting small size and
# high portability, so no magic allowed. Note that the GCC
# version was carefully chosen, not all of them work with LTO.
ENV CFLAGS='-march=x86-64 -Os -fPIC -fuse-linker-plugin -ffunction-sections -fdata-sections'
ENV LDFLAGS='-march=x86-64 -Os -fuse-linker-plugin -Wl,-O1 -Wl,--as-needed'
ENV CC="/opt/lto-toolchain/bin/x86_64-linux-musl-gcc"
ENV AR=/opt/lto-toolchain/bin/x86_64-linux-musl-gcc-ar
ENV CXX=/opt/lto-toolchain/bin/x86_64-linux-musl-g++
ENV RANLIB=/opt/lto-toolchain/bin/x86_64-linux-musl-gcc-ranlib
ENV NM=/opt/lto-toolchain/bin/x86_64-linux-musl-gcc-nm
ENV PREFIX=/opt/lto-toolchain/x86_64-linux-musl/

# Back to Musl, finish the job: Add shared library support. We wont use
# it, but it helps with buggy autotools looking for libc.so in their checks.
# The non-static `luajit` executable will also use it to support `require()`.
# This is used by some scripts in NeoVIM build system.
RUN cd /musl*; CROSS_COMPILE=/opt/lto-toolchain/ ./configure \
    --prefix=/opt/lto-toolchain/x86_64-linux-musl --enable-shared && make clean &&\
    CROSS_COMPILE=/opt/lto-toolchain/ make AR=$AR RANLIB=$RANLIB LD=$LD && make install -j3

# Enable Gold and LTO, for some programs ld.bfd now works.
# This is much better than a few years ago, so gold might
# eventually be retired. However, I still see more LTO
# failures with BFD.
ENV LD=/opt/lto-toolchain/x86_64-linux-musl/bin/ld.gold
ENV CFLAGS='-march=x86-64 -Os -flto -fuse-linker-plugin -ffunction-sections -fdata-sections -fuse-ld=gold'
ENV LDFLAGS='-march=x86-64 -Os -flto=8 -fuse-linker-plugin -Wl,-O1 -Wl,--as-needed -Wl,-flto'

# I despise libtool, it is an horrible idea hiding simple things
# beind a broken abstraction to make everybody life harder.
RUN wget http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz && \
    tar -xpvf libtool*; cd libtoo* && ./configure --prefix=/opt/lto-toolchain/ \
    --host=x86_64-linux-musl --program-prefix=x86_64-linux-musl- \
    --disable-ltdl-install && make install

ENV LIBTOOL=/opt/lto-toolchain/bin/x86_64-linux-musl-libtool

# Below are all NeoVIM dependencies. We build them with static
# library support and LTO.

RUN wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.2.tar.gz; tar -xpvf ncur*; \
    cd ncurses-6.2;./configure \
        --libdir=/opt/lto-toolchain/x86_64-linux-musl/lib \
        --host=x86_64-linux-gnu --target=x86_64-linux-musl \
        --without-cxx \
        --includedir=/opt/lto-toolchain/x86_64-linux-musl/include \
        --prefix=/opt/lto-toolchain/x86_64-linux-musl/ &&\
    make -j12 CXX=$CXX CC=$CC && make install;

RUN cd LuaJIT;\
    sed -i "s|export PREFIX= /usr/local|export PREFIX= $PREFIX|g" Makefile;\
    sed -i "s|DEFAULT_CC = gcc|DEFAULT_CC = $CC -static-libgcc -flto|g" src/Makefile;\
    make -j16 && make install

RUN cd libuv; mkdir -p build; cd build; cmake .. -DBUILD_STATIC_LIBS=ON -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
    -DCMAKE_INSTALL_PREFIX=$PREFIX -DLIBUV_BUILD_TESTS=OFF -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold && \
     make -j12 install

RUN cd unibilium; mkdir -p build; cd build; cmake .. -DBUILD_STATIC_LIBS=ON -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM\
    -DCMAKE_INSTALL_PREFIX=$PREFIX && \
    make -j12 install

# Let it fail, it "works" anyway for the .a
RUN cd libvterm;INCDIR=/opt/lto-toolchain/x86_64-linux-musl/include \
    make CC=$CC PREFIX=$PREFIX && make install PREFIX=$PREFIX || true

RUN cd luv; git pull --recurse-submodules;git submodule update --init --recursive;\
    mkdir -p build; cd build; cmake .. -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM\
    -DBUILD_STATIC_LIBS=ON  -DLUA_BUILD_TYPE=System \
    -DLUAJIT_INCLUDE_DIR=/LuaJIT/src/ -DBUILD_STATIC_LIBS=On \
    -DWITH_SHARED_LIBUV=On -DLIBUV_LIBRARY=/libuv/build/libuv_a.a \
    -DLIBUV_INCLUDE_DIR=/libuv/include/ && make install

RUN cd msgpack-c; mkdir -p build; cd build; cmake .. \
    -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
    -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold\
    -DBUILD_STATIC_LIBS=ON && make -j12 install

RUN wget https://ftp.gnu.org/gnu/readline/readline-8.0.tar.gz && \
    tar -xpvf readlin*; cd readline-8.0;./configure \
    --host=x86_64-linux-gnu --target=x86_64-linux-musl \
    --prefix=/opt/lto-toolchain/x86_64-linux-musl/ && \
    make -j16 install

# Not really "buggy", it's just missing a pkg-config .pc for unibilium,
# hence the hack. Mixing CMake and pkg-config is usually problematic.
RUN cd /libtermke*; CFLAGS="$CFLAGS -DHAVE_UNIBILIUM=1 -l/opt/lto-toolchain/x86_64-linux-musl/lib/libunibilium.a" \
    LDFLAGS="$LDFLAGS /opt/lto-toolchain/x86_64-linux-musl/lib/libunibilium.a" make  libtermkey.la

# Very buggy buildsystem
RUN cd /libmpack-lua/; \
    sed -i 's|/usr/include/|/opt/lto-toolchain/x86_64-linux-musl/include/|g' Makefile; \
    ln -s /opt/lto-toolchain/x86_64-linux-musl/include/luajit-2.1/ /opt/lto-toolchain/x86_64-linux-musl/include/lua5.1; \
    make USE_SYSTEM_LUA=yes

RUN cd lpeg;\
    sed -i "s|CC = gcc|CC = $CC|g" makefile; \
    sed -i "s|LUADIR = ../lua|LUADIR = /LuaJIT/src|g" makefile; \
    make

# .a don't follow depedencies and for better LTO, it is necessary to
# do it at the last minute, so do some pre-linking sanitization
#RUN mkdir /merged; cd merged; \
#    /opt/lto-toolchain/bin/x86_64-linux-musl-gcc-ar -x /ncurses-6.2/lib/libncurses.a; \
#    /opt/lto-toolchain/bin/x86_64-linux-musl-gcc-ar -x /libtermkey/.libs/libtermkey.a;\
#    /opt/lto-toolchain/bin/x86_64-linux-musl-gcc-ar r libncurses_and_termkey.a  *.o

# Enable static linking ans stripping
ENV LDFLAGS='-march=x86-64 -Os -flto=8 -fuse-linker-plugin -Wl,-O1 -Wl,--as-needed -Wl,--gc-sections -Wl,--strip-all -Wl,-flto -static'

# Compile a static NeoVIM
RUN cd neovim; mkdir -p build; cd build; \
    ln -sf /opt/lto-toolchain/x86_64-linux-musl/bin/luajit-2.1.0-beta3 \
    /opt/lto-toolchain/x86_64-linux-musl/bin/luajit; \
    mkdir -p /opt/lto-toolchain/x86_64-linux-musl/lib/lua/5.1/;\
    cp /libmpack-lua/mpack.so /opt/lto-toolchain/x86_64-linux-musl/lib/lua/5.1/;\
    cp /lpeg/lpeg.so /opt/lto-toolchain/x86_64-linux-musl/lib/lua/5.1/;\
    cp /libmpack-lua/mpack.so /opt/lto-toolchain/x86_64-linux-musl/lib/lua/5.1/;\
    cmake .. \
    -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
    -DLIBUV_LIBRARY=/libuv/build/libuv_a.a -DLIBUV_INCLUDE_DIR=/libuv/include/ \
    -DMSGPACK_LIBRARY=/msgpack-c/build/libmsgpackc.a -DMSGPACK_INCLUDE_DIR=/msgpack-c/include/ \
    -DLIBLUV_LIBRARY=/luv/build/libluv_a.a -DLIBLUV_INCLUDE_DIR=/luv/src/ \
    -DLUAJIT_LIBRARY=/LuaJIT/src/libluajit.a -DLUAJIT_INCLUDE_DIR=/LuaJIT/src \
    -DUNIBILIUM_LIBRARY=/unibilium/build/libunibilium.a -DUNIBILIUM_INCLUDE_DIR=/unibilium/ \
    -DLIBTERMKEY_LIBRARY=/libtermkey/.libs/libtermkey.a -DLIBTERMKEY_INCLUDE_DIR=/libtermkey/ \
    -DLIBVTERM_LIBRARY=/libvterm/.libs/libvterm.a -DLIBVTERM_INCLUDE_DIR=/libvterm/ \
    -DLUA_PRG=/LuaJIT/src/luajit -DCMAKE_INSTALL_PREFIX=/opt/neovim-static -DCMAKE_SYSROOT=$PREFIX && make -j16 install

# Now we have our static binary. Rejoice, children of Unix.
# Now lets add an AppImage so we can store the config within
# the binary *and* allow it to be stored in ~/.config/portable-nvim
