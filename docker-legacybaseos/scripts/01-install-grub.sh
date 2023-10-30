#!/bin/bash

echo Installing Grub to /dev/sda
grub-install /dev/sda \
    --target=x86_64-efi \
    --no-uefi-secure-boot \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --removable \
    --force

grub-mkconfig -o /boot/grub/grub.cfg || true
update-grub

# Remove `quiet` because it makes it hard to know when
# `fsck` is running on `systemd` based systems. Which makes
# it confusing to know if the system is actually booting, or
# blocked
sed -i 's/quiet//g' /boot/grub/grub.cfg
