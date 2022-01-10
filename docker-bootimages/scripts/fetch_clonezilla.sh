#!/bin/sh

wget 'https://osdn.net/frs/redir.php?m=xtom_us&f=clonezilla%2F73889%2Fclonezilla-live-2.7.0-10-i686.zip' -O clonezilla.zip || exit 1
unzip -j clonezilla.zip live/vmlinuz live/initrd.img live/filesystem.squashfs -d /tftp/clonezilla/ || exit 1
rm -rf clonezilla.zip || true

