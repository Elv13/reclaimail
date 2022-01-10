# Build the patched dnsmasq
FROM debian:buster-slim as builder
RUN apt update && apt install -y dpkg-dev patch
RUN cp /etc/apt/sources.list /tmp; \
    sed -i 's/deb h/deb-src h/g' /etc/apt/sources.list; \
    cat /tmp/sources.list >> /etc/apt/sources.list
RUN apt update && apt build-dep dnsmasq-base-lua -y &&\
     apt source dnsmasq-base-lua
ADD dnsmasq.patch /dnsmasq-2.80/
RUN cd /dnsmasq-2.80; patch -p1 < ./dnsmasq.patch && \
    DEB_BUILD_OPTIONS='nostrip noopt debug' dpkg-buildpackage -F

FROM elv13/bootimages
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

# Install dependencies
ENV DEBIAN_FRONTEND noninteractive
RUN apt -qq update --fix-missing -y && \
    apt install -y --no-install-recommends \
    wget isc-dhcp-client ifupdown iproute2 locales \
    ca-certificates iptables

# Support UTF-8
ADD locale.gen /etc/
RUN /usr/sbin/locale-gen && touch /etc/dnsmasq.conf
ENV LANG=en_US.utf8
ENV LC_ALL=en_US.UTF-8

COPY --from=builder *.deb /
RUN apt install ./dnsmasq-base-lua*.deb -y && rm -rf /*.deb dnsmasq*

# Use the legacy iptables because it works and bpfilter
# is the future of this project, netfilter is an useless
# stepping stone, skipping.
RUN \
    update-alternatives --set iptables /usr/sbin/iptables-legacy; \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

#TODO split into 2 containers
RUN apt install nfs-kernel-server runit inotify-tools -y
RUN echo '/tftp             10.0.0.0/8(ro,no_root_squash,async,insecure)' > /etc/exports

# Add some files
ADD run.sh rc.lua /
COPY lib/ /usr/share/lua/5.2/reclaim/routing/
ADD iptables_template/* /iptables_template/

#ENTRYPOINT ["/run.sh"]
#CMD /run.sh
