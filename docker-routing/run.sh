#!/bin/sh

# Keep the content across many runs.
if [ -d /persist ]; then
    rm /etc/hosts /etc/ether
    ln -s /persist/hosts /etc/hosts
    ln -s /persist/ether /etc/ether
fi

# Start the DNS, DHCP and PXE server
dnsmasq --dhcp-luascript=/rc.lua -kdq
