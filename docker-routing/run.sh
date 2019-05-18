#!/bin/sh

# WAN (DHCP)
#ifup eno1

# LAN (static)
#ifup enp4s0

# Enable the firewall
#iptables-apply

# Enable routing
#echo 1 > /proc/sys/net/ipv4/ip_forward

# Start the DNS, DHCP and PXE server
dnsmasq -kdq
