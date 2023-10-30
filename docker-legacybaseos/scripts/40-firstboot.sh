#!/bin/bash

# This script creates the `firstboot` user account. This is how
# the user *might* setup the passwords. Some derivative images
# use fully headless embedded devices, so ssh or RS-232/UART are
# the only way to finish the setup. Plus it avoid having to add
# a default root password.

adduser firstboot
echo 'firstboot:1234' | chpasswd
mkdir -p /home/firstboot
chown firstboot:firstboot /home/firstboot
cat > /home/firstboot/root_passwd.sh << EOF
#!/bin/bash
passwd root
rm -rf  /home/firstboot/
EOF

chown root:root /home/firstboot/root_passwd.sh
chmod +xs /home/firstboot/root_passwd.sh

# Create user
cat > /home/firstboot/.bashrc << EOF
echo Welcome to ReclaimOS.

# Better than no security...
if [ "$SSH_CLIENT" != "" ]; then
    DUMB_192_MASK=$(echo $SSH_CLIENT | grep -E "192[.]168[.][0-9]+[.][0-9]+")
    DUMB_10_MASK=$(echo $SSH_CLIENT | grep -E "10[.][0-9]+[.][0-9]+[.][0-9]")
    DUMB_IPV6=$(echo $SSH_CLIENT | grep ":")

    # Too many corner cases. There is no such thing as IPv6 only LANs.
    if [ "$DUMB_IPV6" != "" ]; then
        echo Setup from IPv6 is not supported, use IPv4
        exit 1
    fi

    # Never allow setup from glabally routable addresses.
    if [ "$DUMB_192_MASK$DUMB_10_MASK" == "" ]; then
        echo "The setup only exist within a local network."
        echo "Connect over 192.168.0.0/16 or 10.0.0.0/8"
        exit 2
    fi
fi

echo
echo Enter username:
read NEW_USER
adduser $NEW_USER
mkdir /home/$NEW_USER -p
chown $NEW_USER:$NEW_USER /home/$NEW_USER
echo Enter $NEW_USER password:
passwd $NEW_USER
echo Enter root password:
/home/firstboot/root_passwd.sh
echo Setup completed!

echo Enable SSH? (y/n)
read ENABLE_SSH

if [ "ENABLE_SSH" == "y" ]; then
    apt install -y openssh-server
fi

echo Save uEFI boot order? (y/n) (do *not* use on BIOS)
read SAVE_BOOT

if [ "$SAVE_BOOT" == "y" ]; then
    EFI_CURRENT=$(efibootmgr | grep BootCurrent | cut -f2 -d' ')
    if [ "$EFI_CURRENT" != "" ]; then

        echo "Disable all other boot devices? (y/n)
        read DISABLE_EFI_DEVS

        if [ "$DISABLE_EFI_DEVS" == "y" ]; then
            efibootmgr \
                | grep -E '^[a-zA-Z0-9]+[*]' \
                | grep -v $EFI_CURRENT \
                | grep -Eo '0[0-9A-F]+[*]' \
                | grep -Eo '0[0-9A-F]+' \
                | xargs -n1 efibootmgr -A -b > /dev/null
            efibootmgr
        else
            efibootmgr \
                | grep -E '^[a-zA-Z0-9]+[*]' \
                | grep -v $EFI_CURRENT \
                | grep -Eo '0[0-9A-F]+[*]' \
                | grep -Eo '0[0-9A-F]+' \
                | xargs -i echo -en ,{} \
                | xargs -i efibootmgr --bootorder ${EFI_CURRENT}{} && \
                    echo "Boot order updated!" || \
                    echo "Failed to update boot order"
        end
    else
        echo Failed to update boot order.
    fi
fi

exit 0
EOF

systemctl enable firstboot.service
