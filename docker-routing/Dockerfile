FROM debian:sid-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

# Install dependencies
ENV DEBIAN_FRONTEND noninteractive
RUN apt -qq update --fix-missing -y && \
    apt install -y --no-install-recommends \
    wget isc-dhcp-client ifupdown iproute2 locales \
    ca-certificates iptables pxelinux syslinux-common

# Support UTF-8
ADD locale.gen /etc/
RUN /usr/sbin/locale-gen && touch /etc/dnsmasq.conf
ENV LANG=en_US.utf8
ENV LC_ALL=en_US.UTF-8

# Setup the syslinux tftp server
RUN mkdir /tftp && cp /usr/lib/PXELINUX/pxelinux.0 /tftp/ && \
    cp /usr/lib/syslinux/modules/bios/* /tftp/

# Add some files
ADD run.sh rc.lua lib/* /
ADD network/* /etc/network/

#ENTRYPOINT ["/run.sh"]
#CMD /run.sh
