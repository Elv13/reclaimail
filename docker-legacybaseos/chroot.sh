DEV=$1
mount /dev/${DEV}2 /mnt/usb
mount /dev/${DEV}1 /mnt/usb/boot/efi
mount -o bind /dev /mnt/usb/dev
mount -o bind /dev/pts /mnt/usb/dev/pts
mount -o bind /proc /mnt/usb/proc/
mount -o bind /sys /mnt/usb/sys/
mount --bind /sys/firmware/efi/efivars /mnt/usb/sys/firmware/efi/efivars
chroot /mnt/usb
umount /mnt/usb/dev/pts
umount /mnt/usb/boot/efi
umount /mnt/usb/sys/firmware/efi/efivars
umount /mnt/usb/*
umount /mnt/usb/
eject /dev/${DEV}
