#!/bin/sh
wget http://old-releases.ubuntu.com/releases/8.04.0/ubuntu-8.04.4-desktop-i386.iso

guestfish << EOF
echo add
add-ro ubuntu-8.04.4-desktop-i386.iso
echo run
run
echo mount
mount /dev/sda /
echo copy
copy-out /casper/filesystem.squashfs /
EOF

unsquashfs -d ubuntu804/ filesystem.squashfs
mkdir -p /tftp/
ls ubuntu804/ -l
cp /ubuntu804/usr/lib/syslinux /tftp/ -av
rm -rf filesystem.squashfs  ubuntu804
