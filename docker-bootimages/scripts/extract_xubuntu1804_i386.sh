#!/bin/sh

mkdir -p /tftp/xubuntu1804/
wget http://cdimage.ubuntu.com/xubuntu/releases/18.04.5/release/xubuntu-18.04.5-desktop-i386.iso

guestfish << EOF
echo add
add-ro $(ls /*xubuntu-18.04.5-desktop-i386.iso*)
echo run
run
echo mount
mount /dev/sda1 /
echo copy
copy-out / /tftp/xubuntu1804/
EOF

rm /*xubuntu-18.04.5-desktop-i386.iso* || true
