#!/bin/sh

wget 'https://downloads.sourceforge.net/project/gparted/gparted-live-stable/1.1.0-8/gparted-live-1.1.0-8-i686.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fgparted%2Ffiles%2Fgparted-live-stable%2F1.1.0-8%2Fgparted-live-1.1.0-8-i686.zip%2Fdownload%3Fuse_mirror%3Diweb&ts=1610921439&use_mirror=iweb' -O gparted.zip || exit 1
unzip -j gparted.zip live/vmlinuz live/initrd.img live/filesystem.squashfs -d /tftp/gparted/ || exit 1
rm -rf gparted.zip || true

