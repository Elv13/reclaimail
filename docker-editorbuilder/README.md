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

# Editor usage

```
./nvim.appimage
```

read `rc.lua` for the keybindings
