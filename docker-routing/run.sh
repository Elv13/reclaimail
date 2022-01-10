#!/bin/sh

# Start the DNS, DHCP and PXE server
dnsmasq --dhcp-luascript=/rc.lua -kdq
