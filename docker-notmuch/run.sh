#! /bin/sh

LUA_PATH=$(luajit -e "print(package.path)")
LUA_CPATH=$(luajit -e "print(package.cpath)")

LUA_PATH="$LUA_PATH;$HOME/LPeg-Parsers-master/?.lua"
LUA_CPATH="$LUA_CPATH;$HOME/LPeg-Parsers-master/?.so"
LUA_PATH="$LUA_PATH;$HOME/notmuchlua/?.lua"

export LUA_PATH=$LUA_PATH
export LUA_CPATH=$LUA_CPATH

# Add (or update) the maildir hooks
mkdir -p ~/GMail/.notmuch/hooks
cp hooks/* ~/GMail/.notmuch/hooks

luajit $HOME/notmuchlua/process.lua
