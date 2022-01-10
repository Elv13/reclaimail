#!/bin/sh

wget https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2020-12-04/2020-12-02-raspios-buster-armhf-lite.zip
unzip *rasp*.zip
mkdir -p /tftp/rpi/ /tftp/rpi_root/
rm *.zip

guestfish << EOF
echo add
add-ro $(ls /*raspios*.img)
echo run
run
echo mount
mount /dev/sda1 /
echo copy kernel
copy-out / /tftp/rpi/
echo copy root
umount /dev/sda1
mount /dev/sda2 /
copy-out / /tftp/rpi_root/
EOF
