# reclaim editor

A custom version of NeoVIM built statically and stripped of a lot
of content (including all of the doc) to fit in the smallest AppImage
possible.

It comes with a config written in pure Lua. The config re-implement most
of `nano` and some of `kate` and `vscode` keybindinds in the `INSERT` mode.

It still has the usual vim NORMAL, but with some different settings. So it
might be confusing to use if you like vim. But very easy to use if you use
any other GUI editor created in the last 30 years.

# Dockerfile Usage

```lua
docker build . -t reclaim/nvim
docker run --rm -v $PWD:/export/ -ti reclaim/nvim
```

This should add a `nvim.appimage` to the current directory.

Note that if you change the config and rely on a theme, edit
`build.sh` to *not* delete it.

The docker build options are:

    COMPILE_x86_64   : Build the AMD64 version
    COMPILE_i686     : Build the 32bit version
    COMPILE_aarch64  : Cross compile for ARM
    GCC_VERSION      : The GCC version (default to 9.3)
    PARALLEL         : Set to #CPU + 1


# Editor usage

```
./nvim.appimage
```

read `rc.lua` for the keybindings
