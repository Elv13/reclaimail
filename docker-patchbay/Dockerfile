
# Compile a custom lzmq for Lua 5.2. Debian LuaRocks is for
# 5.1. Patchbay doesn't support 5.1 because it cannot yield
# coroutines across metacalls. metacalls are literally the
# tech on which the AwesomeWM/Reclaim object system is built upon.
FROM debian:bullseye-slim as lzmq

RUN apt update && apt install cmake liblua5.2-dev libzmq5-dev git build-essential wget libphonenumber-dev libicu-dev -y

RUN git clone https://github.com/zeromq/lzmq.git && \
    rm -rf /usr/include/lua5.1 && \
    mkdir lzmq/build && \
    cd lzmq/build && \
    cmake .. && \
    make

RUN wget https://gitlab.kuleuven.be/u0129795/lua-json-rpc/-/raw/master/src/json-rpc.lua

RUN git clone https://github.com/Elv13/luaphonenumber.git && \
    cd luaphonenumber && \
    make CXXFLAGS="-llua5.2-c++ -I/usr/include/lua5.2/ -DLUA_COMPAT_MODULE=1 -std=c++11 -Wall -fPIC"

# Their makefile require luarocks, which only comes in 5.1 variant in Debian
RUN git clone https://github.com/facebook/luaffifb && \
    cd luaffifb && \
    gcc -I/usr/include/lua5.2/ -shared -fPIC -o /ffi.so $(ls *.c | grep -v test)

FROM debian:bullseye-slim

RUN apt update && apt install lua5.2 liblua5.2-0 lua-posix \
    lua-logging lua-json lua-coxpcall libzmq5 libphonenumber8 libgeocoding8 -y

COPY --from=lzmq /lzmq//build/lzmq.so /usr/lib/lua/5.2/
COPY --from=lzmq /ffi.so /usr/lib/lua/5.2/
COPY --from=lzmq /lzmq/build/lzmq/ /usr/lib/lua/5.2/lzmq/
COPY --from=lzmq /luaphonenumber/luaphonenumber.so.1.0 /usr/lib/lua/5.2/luaphonenumber.so
COPY --from=lzmq /json-rpc.lua /

ADD *.lua /
ADD patchbay /usr/share/lua/5.1/patchbay
