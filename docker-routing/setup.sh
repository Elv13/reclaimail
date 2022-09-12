#!/bin/bash

# Get the list of network interfaces
function interfaces() {
    ls /sys/class/net
}

# Get the Mac address for an interface
function address() {
    cat /sys/class/net/$1/address
}

function print_choices() {
    COUNT=0
    for INTERFACE in $(interfaces); do
        if [ "${!INTERFACE}" == "" ]; then
            printf "${INTERFACE}: ${COUNT}, "
            let COUNT++
        fi
    done

    printf "Choice: "

    return $COUNT
}

# Convert the number to the interface name
function choice_to_iface() {
    COUNT=0
    for INTERFACE in $(interfaces); do
        if [ "${!INTERFACE}" == "" ]; then
            if [ $1 == $COUNT ]; then
                 echo $INTERFACE
                 return 0
            fi
            let COUNT++
        fi
    done

    return 1
}

# Prompt the choices
function choices() {
    while true; do
        COUNT=$!

        read RES

        INTERFACE=$(choice_to_iface $RES)

        if [ "$?" == "0" ]; then
            export $INTERFACE=$1
            export $1=$INTERFACE
        else
            echo Enter a valid number
        fi

        break
    done
}

if [ -e ~/.config/reclaim/routing/iface.ini ]; then
    # Load from the config
    LAN_MAC=$(grep lan_address ~/.config/reclaim/routing/iface.ini | cut -f2 -d=)
    WAN_MAC=$(grep wan_address ~/.config/reclaim/routing/iface.ini | cut -f2 -d=)
    WLAN_MAC=$(grep wlan_address ~/.config/reclaim/routing/iface.ini | cut -f2 -d=)
else

    while [ "$WIFI" != "y" ] && [ "$WIFI" != "n" ]; do
        echo -n "Enable wifi? [y/n]: "
        read WIFI
    done

    # Build the config
    echo "Select the Internet facing interface (WAN) $(print_choices) :"

    choices WAN_IFACE

    echo "Select the Local facing interface (LAN) $(print_choices) :"
    choices LAN_IFACE

    if [ $WIFI == y ]; then
        echo "Select the Wireless interface (WLAN) $(print_choices) :"
        choices WLAN_IFACE
    fi

    LAN_MAC=$(address $LAN_IFACE)
    WAN_MAC=$(address $WAN_IFACE)

    echo LAN IS $LAN_IFACE $LAN_MAC
    echo WAN IS $WAN_IFACE $WAN_MAC

    if [ $WIFI == y ]; then
        WLAN_MAC=$(address $WLAN_IFACE)
    fi

    mkdir -p ~/.config/reclaim/routing/

    echo "[interfaces]" > ~/.config/reclaim/routing/iface.ini
    echo "lan_address=$LAN_MAC" >> ~/.config/reclaim/routing/iface.ini
    echo "wan_address=$WAN_MAC" >> ~/.config/reclaim/routing/iface.ini

    if [ $WIFI == y ]; then
        echo "wlan_address=$WLAN_MAC" >> ~/.config/reclaim/routing/iface.ini
    fi

    echo "127.0.0.1 localhost" > ~/.config/reclaim/routing/hosts
    touch ~/.config/reclaim/routing/ether
    touch ~/.config/reclaim/routing/dnsmasq.leases
    touch ~/.config/reclaim/routing/dnsmasq.hosts

    if [ ! -e ~/.config/reclaim/routing/rc.lua ]; then
        cp ./rc.lua ~/.config/reclaim/routing/rc.lua
    fi
fi

docker build . -t reclaim/routing

docker run -ti\
    --privileged \
    --net host \
    --env "LAN_MAC=$LAN_MAC" \
    --env "WAN_MAC=$WAN_MAC" \
    --env "WLAN_MAC=$WLAN_MAC" \
    -v ~/.config/reclaim/routing/hosts:/etc/hosts \
    -v ~/.config/reclaim/routing/ethers:/etc/ethers \
    -v ~/.config/reclaim/routing/dnsmasq.leases:/etc/dnsmasq.leases \
    -v ~/.config/reclaim/routing/dnsmasq.hosts:/etc/dnsmasq.hosts \
    -v /tmp:/tmp \
    -v $HOME/dnsmasq-2.80:/dnsmasq-2.80 \
    --device=/dev/loop-control:/dev/loop-control \
    -v /mnt/sdc1/ISO:/ISO \
    -t reclaim/routing
    #./run.sh
