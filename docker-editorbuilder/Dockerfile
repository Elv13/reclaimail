# This Dockerfile creates a very small AppImage using static
# linking and LTO. It is 100% portable for all x86_64 *OR*
# aarch64 systems.
#
# The general idea is to create a single file you can `scp`
# into all of your system and have a Lua based self contained
# config "just working".
#
# This Dockerfile goes out of its way to setup a proper
# cross compile toolchain for the sake of saving a kilobit...
# This also means ingnoring all the goodies of neovim build
# system because "I know better". Still, given how it's used
# and how the Reclaim project is hardened, it makes sense
# to share a static editor across the project.
FROM debian:buster-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

ARG COMPILE_x86_64=1
ARG COMPILE_i686
ARG COMPILE_aarch64
ARG GCC_VERSION=9.3.0
ARG LIBTOOL_VERSION=2.4.6
ARG NCURSES_VERSION=6.2
ARG BINUTILS_VERSION=2.34
ARG READLINE_VERSION=8.0
ARG PARALLEL=16

ENV PSIZE="${COMPILE_i686:+-m32}"
ENV ARCH="${COMPILE_x86_64:+x86_64}${COMPILE_i686:+i686}${COMPILE_aarch64:+aarch64}"
ENV MARCH="${COMPILE_x86_64:+x86-64}${COMPILE_i686:+i686}${COMPILE_aarch64:+aarch64}"

# Make sure to upgrade so ca-certificate is up-to-date
RUN apt update && apt upgrade -y && apt install -y build-essential git cmake  \
    pkg-config libtool-bin wget curl gperf gettext texinfo

RUN wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

RUN git clone https://github.com/neovim/neovim.git --depth 1 &&                 \
    git clone https://github.com/libuv/libuv.git --depth 1 &&                   \
    git clone https://github.com/msgpack/msgpack-c.git -b c_master --depth 1 && \
    git clone https://github.com/luvit/luv.git --depth 1 &&                     \
    git clone https://github.com/LuaJIT/LuaJIT.git -b v2.1 --depth 1 &&         \
    git clone https://github.com/neovim/unibilium.git --depth 1 &&              \
    git clone https://github.com/neovim/libtermkey.git --depth 1 &&             \
    git clone https://github.com/neovim/libvterm.git --depth 1 &&               \
    git clone https://github.com/luvit/lpeg.git --depth 1 &&                    \
    git clone https://github.com/libmpack/libmpack-lua.git --depth 1 &&         \
    git clone https://github.com/tree-sitter/tree-sitter.git --depth 1 &&       \
    git clone git://git.musl-libc.org/musl --depth 1

# Compile binutils, just because we have a custom GCC...
RUN wget https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.bz2 && \
    tar -xpvf binut*; \
    cd binut*; \
    ./configure --prefix=/opt/lto-toolchain \
        --target=${ARCH}-linux-musl --disable-multilib --disable-nls --enable-gold=yes\
        --disable-werror && \
    make -j${PARALLEL} && \
    make install && \
    cd /; \
    rm -rf binut*

# Install Ancient Linux kernel headers. This will make sure we
# don't use systemcall newer than CentOS 6.0 (2010). This is
# the oldest system we can assume to work. Older RHEL were not
# super good at 64 bit anyway. If anyone still uses 10+ years
# old Ubuntu, they are insane. People with retro-computing
# are not on 64bit. So this kernel should work for everybody
# (using Linux).
RUN wget https://mirrors.edge.kernel.org/pub/linux/kernel/v2.6/linux-2.6.32.1.tar.bz2; \
    tar -xpvf linux-*; \
    cd linux-2.6.32.1; \
    make ARCH=$ARCH INSTALL_HDR_PATH=/opt/lto-toolchain/${ARCH}-linux-musl headers_install; \
    cd /; \
    rm -rf linux-2*

# Let's build GCC, everybody loves building custom GCCs, right?
# The real reason is to disable thread local storage. LuaJIT
# doesn't use pthread for portability, which means it is also
# pretty dumb because it doesn't re-implement all the safety
# logic pthread provides. If it wasn't for this issue, the
# `musl-tools` GCC config included in Debian would have worked.
RUN wget https://ftpmirror.gnu.org/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz; \
    tar -xpvf gcc*; \
    cd gcc*; \
    contrib/download_prerequisites;\
    mkdir build-src; \
    cd build-src; \
    CFLAGS="-Os" ../configure --disable-tls \
        --disable-multilib --enable-languages=c --disable-libstdcxx  --disable-nls \
        --disable-libgomp --disable-libitm --disable-libquadmath                   \
        --disable-libsanitizer --disable-libssp --disable-libvtv                   \
        --disable-libstdc__-v3 --enable-lto --enable-gold=yes --enable-ld=no       \
        --target=${ARCH}-linux-musl --host=x86_64-linux-gnu --disable-bootstrap    \
        --enable-kernel=2.6.32.1 --prefix=/opt/lto-toolchain                       \
        --with-nonshared-cflags="-Os" && \
    make -j${PARALLEL} all-gcc && \
    make install-gcc; \
    rm -rf ./*

# We need a custom built musl for this, otherwise it will
# abort when LuaJIT tries to use too much stack. We also need
# to enable LTO. In my testing, 256kB never had issues, 128kB
# crashed a couple time. Note that it is important to set the
# variables for CC, CFLAGS and LD directly. We can't enable
# LTO yet and can't set the ENV because GCC in the next step
# still uses the host compiler.
RUN cd musl* && \
    export CFLAGS="-Os -fPIC -march=$MARCH"; \
    sed -i 's/DEFAULT_STACK_SIZE 131072/DEFAULT_STACK_SIZE 262144/' src/internal/pthread_impl.h && \
    CC=/opt/lto-toolchain/bin/${ARCH}-linux-musl-gcc LD=/opt/lto-toolchain/bin/${ARCH}-linux-musl-ld \
    CROSS_COMPILE=/opt/lto-toolchain/ ./configure \
        --prefix=/opt/lto-toolchain/${ARCH}-linux-musl --disable-shared && \
    CC=/opt/lto-toolchain/bin/${ARCH}-linux-musl-gcc LD=/opt/lto-toolchain/bin/${ARCH}-linux-musl-ld \
    CROSS_COMPILE=/opt/lto-toolchain/ make \
        AR=/opt/lto-toolchain/bin/${ARCH}-linux-musl-ar \
        RANLIB=/opt/lto-toolchain/bin/${ARCH}-linux-musl-ranlib && \
    make install

# Back to GCC, finish the job: add C++, libgcc and libstdc++
# (msgpack *needs* it, but doesn't *use* it...). Note that GCC must
# be compiled in 2 steps to do a bootstrap because it needs the libc
# header and the libc header are slightly dependant on the compiler
# setup.
RUN cd /gcc*/build-src; \
    ../configure \
        --disable-tls --disable-multilib --enable-languages=c,c++            \
        --disable-bootstrap --disable-nls --disable-libssp --disable-libvtv  \
        --disable-libsanitizer --disable-libgomp --disable-libitm            \
        --enable-lto --enable-gold=yes --enable-ld=yes                       \
        --target=${ARCH}-linux-musl --host=x86_64-linux-gnu                  \
        --prefix=/opt/lto-toolchain && \
    make -j${PARALLEL} && \
    make install; \
    rm -rf ./*

# Nothing special here, we are targetting small size and
# high portability, so no magic allowed. Note that the GCC
# version was carefully chosen, not all of them work with LTO.
ENV CFLAGS=" \
    -march=$MARCH \
    $PSIZE \
    -Os \
    -fuse-linker-plugin \
    -ffunction-sections \
    -fdata-sections \
    -fno-stack-protector \
    ${COMPILE_i686:+-fomit-frame-pointer} \
    ${COMPILE_i686:+-mpreferred-stack-boundary=2} \
    ${COMPILE_i686:+-falign-functions=1 -falign-jumps=1 -falign-loops=1} \
    -fmerge-all-constants"

ENV LDFLAGS=" \
    $CFLAGS \
    -fuse-linker-plugin \
    -Wl,-O1 \
    -Wl,--as-needed \
    -Wl,--gc-sections \
    -Wl,-z,norelro \
    -Wl,--hash-style=gnu \
    -Wl,--build-id=none"

ENV CC="/opt/lto-toolchain/bin/${ARCH}-linux-musl-gcc ${PSIZE}"
ENV AR="/opt/lto-toolchain/bin/${ARCH}-linux-musl-gcc-ar"
ENV CXX="/opt/lto-toolchain/bin/${ARCH}-linux-musl-g++"
ENV RANLIB="/opt/lto-toolchain/bin/${ARCH}-linux-musl-gcc-ranlib"
ENV NM="/opt/lto-toolchain/bin/${ARCH}-linux-musl-gcc-nm"
ENV PREFIX="/opt/lto-toolchain/${ARCH}-linux-musl/"

# Back to Musl, finish the job: Add shared library support. We wont use
# it, but it helps with buggy autotools looking for libc.so in their checks.
# The non-static `luajit` executable will also use it to support `require()`.
# This is used by some scripts in NeoVIM build system.
RUN cd /musl*; \
    CROSS_COMPILE=/opt/lto-toolchain/ ./configure \
        --prefix=/opt/lto-toolchain/${ARCH}-linux-musl --enable-shared && \
    make clean &&\
    CROSS_COMPILE=/opt/lto-toolchain/ make AR=$AR RANLIB=$RANLIB LD=$LD && \
    make install -j${PARALLEL}

# Enable Gold and LTO, for some programs ld.bfd now works.
# This is much better than a few years ago, so gold might
# eventually be retired. However, I still see more LTO
# failures with BFD. Also now enable fast-math, because
# it doesn't explode, so why not.
ENV LD="/opt/lto-toolchain/${ARCH}-linux-musl/bin/ld.gold"
ENV CFLAGS="$CFLAGS -fuse-ld=gold -flto=8 -ffast-math"
ENV LDFLAGS="$LDFLAGS -flto=8 -ffast-math -Wl,-flto"

# I despise libtool, it is an horrible idea hiding simple things
# beind a broken abstraction to make everybody life harder.
RUN wget http://ftpmirror.gnu.org/libtool/libtool-${LIBTOOL_VERSION}.tar.gz && \
    tar -xpvf libtool*; \
    cd libtoo* && \
    ./configure --prefix=/opt/lto-toolchain/ \
        --host=${ARCH}-linux-musl --program-prefix=${ARCH}-linux-musl- \
        --disable-ltdl-install && \
    make install

ENV LIBTOOL="/opt/lto-toolchain/bin/${ARCH}-linux-musl-libtool"

# Below are all NeoVIM dependencies. We build them with static
# library support and LTO.

RUN wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz; \
    tar -xpvf ncur*; \
    cd ncurses-${NCURSES_VERSION}; \
    ./configure \
        --libdir=/opt/lto-toolchain/${ARCH}-linux-musl/lib \
        --host=x86_64-linux-gnu --target=${ARCH}-linux-musl \
        --without-cxx \
        --includedir=/opt/lto-toolchain/${ARCH}-linux-musl/include \
        --prefix=/opt/lto-toolchain/${ARCH}-linux-musl/ &&\
    make -j${PARALLEL} CXX=$CXX CC=$CC && \
    make install;

# LuaJIT Makefiles are hardcoded. They claim to support passing everything
# as variables, but it doesn't actually work, hence the `sed` calls.
RUN cd LuaJIT; \
    export LUAJIT_CFLAGS="-Os $PSIZE -static-libgcc -fno-function-sections -fno-data-sections"; \
    sed -i "s|export PREFIX= /usr/local|export PREFIX= /opt/lto-toolchain/${ARCH}-linux-musl/|g" Makefile; \
    sed -i "s|DEFAULT_CC = gcc|DEFAULT_CC = $CC $LUAJIT_CFLAGS|g" src/Makefile; \
    CFLAGS="$LUAJIT_CFLAGS" LDFLAGS="$LUAJIT_CFLAGS -Wl,-O1" make \
        PREFIX="$PREFIX"\
        CC="/opt/lto-toolchain/bin/${ARCH}-linux-musl-gcc $LUAJIT_CFLAGS" \
        HOST_CFLAGS="$LUAJIT_CFLAGS" \
        HOST_LDFLAGS="$LUAJIT_CFLAGS" \
        TARGET_CFLAGS="$LUAJIT_CFLAGS" \
        TARGET_LDFLAGS="$LUAJIT_CFLAGS" \
        PREFIX="$PREFIX" -j${PARALLEL} && \
    make install PREFIX=/opt/lto-toolchain/${ARCH}-linux-musl/ && \
    ln -s /opt/lto-toolchain/${ARCH}-linux-musl/share/luajit-2.1.0-beta3/jit/ \
        /opt/lto-toolchain/${ARCH}-linux-musl/lib/lua/5.1/

RUN cd libuv; \
    mkdir -p build; \
    cd build; \
    cmake .. -DBUILD_STATIC_LIBS=ON \
        -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
        -DCMAKE_INSTALL_PREFIX=$PREFIX -DLIBUV_BUILD_TESTS=OFF \
        -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold && \
    make -j${PARALLEL} install

RUN cd unibilium; \
    mkdir -p build; \
    cd build; cmake .. \
        -DBUILD_STATIC_LIBS=ON -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM\
        -DCMAKE_INSTALL_PREFIX=$PREFIX && \
    make -j${PARALLEL} install

# Let it fail, it "works" anyway for the .a
RUN cd libvterm;INCDIR=/opt/lto-toolchain/${ARCH}-linux-musl/include \
    make CC=$CC PREFIX=$PREFIX && \
    make install PREFIX=$PREFIX || true

RUN cd luv; \
    git pull --recurse-submodules; \
    git submodule update --init --recursive;\
    mkdir -p build; \
    cd build; \
    cmake .. -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_AR=$AR \
        -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
        -DBUILD_STATIC_LIBS=ON  -DLUA_BUILD_TYPE=System \
        -DLUAJIT_INCLUDE_DIR=/LuaJIT/src/ -DBUILD_STATIC_LIBS=On \
        -DWITH_SHARED_LIBUV=OFF -DLIBUV_LIBRARY=/libuv/build/libuv_a.a \
        -DLIBUV_INCLUDE_DIR=/libuv/include/ && \
    make install

RUN cd msgpack-c; \
    mkdir -p build; \
    cd build; \
    cmake .. \
        -DCMAKE_AR=$AR -DCMAKE_LINKER=$LD -DCMAKE_NM=$NM \
        -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold\
        -DBUILD_STATIC_LIBS=ON && \
    make -j${PARALLEL} install

RUN wget https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz && \
    tar -xpvf readlin*; \
    cd readline-${READLINE_VERSION}; \
    ./configure \
        --host=x86_64-linux-gnu --target=${ARCH}-linux-musl \
        --prefix=/opt/lto-toolchain/${ARCH}-linux-musl/ && \
    make -j${PARALLEL} install

# Not really "buggy", it's just missing a pkg-config .pc for unibilium,
# hence the hack. Mixing CMake and pkg-config is usually problematic.
RUN cd /libtermke*; \
    CFLAGS="$CFLAGS -DHAVE_UNIBILIUM=1 -l/opt/lto-toolchain/${ARCH}-linux-musl/lib/libunibilium.a" \
    LDFLAGS="$LDFLAGS /opt/lto-toolchain/${ARCH}-linux-musl/lib/libunibilium.a" make libtermkey.la

# Very buggy buildsystem
RUN cd /libmpack-lua/; \
    sed -i 's|/usr/include/|/opt/lto-toolchain/${ARCH}-linux-musl/include/|g' Makefile; \
    ln -s /opt/lto-toolchain/${ARCH}-linux-musl/include/luajit-2.1/ \
        /opt/lto-toolchain/${ARCH}-linux-musl/include/lua5.1; \
    make USE_SYSTEM_LUA=yes

# Technically, no need to go crazy here. It's a built-time dep.
RUN cd lpeg;\
    sed -i "1s|^|LDFLAGS=$LDFLAGS\n|" makefile; \
    sed -i "s|-fPIC|$CFLAGS $PSIZE -fPIC|g" makefile; \
    sed -i "s|CC = gcc|CC = $CC|g" makefile; \
    sed -i "s|LUADIR = ../lua|LUADIR = /LuaJIT/src|g" makefile; \
    sed -i "s|-fPIC|-fPIC $CFLAGS|g" makefile; \
    make

# Install tree-sitter
RUN cd tree-sitter && \
    make install -j${PARALLEL} && \
    rm /opt/lto-toolchain/${ARCH}-linux-musl/lib/libtree-sitter.so*

# Enable static linking and stripping
ENV LDFLAGS="$LDFLAGS -Wl,--gc-sections -Wl,--strip-all -Wl,-flto -static"
ENV LUA_CPATH="?;?.lua;/opt/lto-toolchain/${ARCH}-linux-musl/lib/lua/5.1/?.so;"
ENV LUA_PATH="?;?.lua;/opt/lto-toolchain/${ARCH}-linux-musl/lib/lua/5.1/?/?.lua;/opt/lto-toolchain/${ARCH}-linux-musl/lib/lua/5.1/?.lua"

# Last minute fixups
RUN ln -sf /opt/lto-toolchain/${ARCH}-linux-musl/bin/luajit-2.1.0-beta3 \
        /opt/lto-toolchain/${ARCH}-linux-musl/bin/luajit; \
    mkdir -p /opt/lto-toolchain/${ARCH}-linux-musl/lib/lua/5.1/;\
    cp /lpeg/lpeg.so /opt/lto-toolchain/${ARCH}-linux-musl/lib/lua/5.1/;\
    cp /libmpack-lua/mpack.so /opt/lto-toolchain/${ARCH}-linux-musl/lib/lua/5.1/;

ADD build.sh /
ADD AppRun nvim.desktop vim.xpm /opt/neovim-static/

RUN chmod +x appimagetool-x86_64.AppImage && \
    ./appimagetool-x86_64.AppImage --appimage-extract && \
    mv /squashfs-root/ /appimagetool

ENV PATH=$PATH:/appimagetool/usr/bin/:LuaJIT/src/

ADD nvim/ /opt/neovim-static/etc/nvim/

# Now we have our static binary. Rejoice, children of Unix.
# Now lets add an AppImage so we can store the config within
# the binary *and* allow it to be stored in ~/.config/portable-nvim

# Compile a static NeoVIM
ENTRYPOINT /build.sh
