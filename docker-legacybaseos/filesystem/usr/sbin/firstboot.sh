#!/bin/bash

# This script finish the installation, then self destruct.
ROOT_PART=$(mount | grep " / " | awk '{print $1}')
ROOT_DEV=/dev/$(lsblk -no pkname $ROOT_PART)

# Resize the partition
echo -e "Fix\n2\nYes\n100%" | parted ---pretend-input-tty $ROOT_DEV resizepart ||
    echo -e "2\nYes\n100%" | parted ---pretend-input-tty $ROOT_DEV resizepart

# Resize XFS
xfs_growfs $ROOT_PART

mount -o remount /

# Self destruct
systemctl disable firstboot
rm /etc/systemd/system/firstboot.service /usr/bin/firstboot.sh -f
