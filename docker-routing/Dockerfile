FROM debian:sid-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

# Install dependencies
ENV DEBIAN_FRONTEND noninteractive
RUN apt -qq update --fix-missing -y
RUN apt install -y --no-install-recommends \
    wget isc-dhcp-client ifupdown iproute2 locales \
    ca-certificates dnsmasq-base-lua iptables

# Support UTF-8
ADD locale.gen /etc/
RUN /usr/sbin/locale-gen
ENV LANG=en_US.utf8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color

# Setup the tftp server
RUN mkdir /tftp
RUN cd /tftp && wget archive.ubuntu.com/ubuntu/dists/precise/main/installer-i386/current/images/netboot/netboot.tar.gz && \
   tar -xpvf ./*.gz && rm netboot.tar.gz

# Add the routing config
RUN echo conf-dir=/etc/dnsmasq.d/,*.conf >> /etc/dnsmasq.conf

# Add some files
ADD run.sh         /
ADD dnsmasq.d/*    /etc/dnsmasq.d/
ADD network/*      /etc/network/
ADD *.lua          /
ADD lib/*           /

#ENTRYPOINT ["/run.sh"]
#CMD /run.sh
