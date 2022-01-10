# This Dockerfile downloads and setup a bunch of useful and
# historically relevant network boot images. It indents to cover:
#
# * SBC / RaspberriPi / Pine netboot images
# * Computer repair and maintainance tools
# * Backups and restore
# * Common PC OSes
# * SIP Phones firmwares
# * Classic retro computing content
# * Containerd/docker base images
#
# This is a base container for the PXE/tftp server and NFS
# server which are needed to turn this into something useful.
# It cannot only be done using TFTP because that requires to
# upload the entire images as RAM-disks, which is impossible
# on lower end (including recent ones like the 2Gb RaspberriPis).

# Use the Ubuntu 10.04 syslinux because it works perfectly
# for BIOS based systems and anything newer works less.
# Ideally, it should switch to a newer one when 64bit support
# is detected.
FROM ubuntu:10.04 as legacy_syslinux

# Use an ancient Ubuntu because it's pxelinux.0 is the least buggy
# for BIOS based computers. Everything newer supports less hardware.
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu/|g' /etc/apt/sources.list
RUN apt-get update && apt-get install syslinux -y && mkdir /tftp/ && \
    cp /usr/lib/syslinux/ /tftp/ -a

# Get syslinux and the Raspberri Pi boot TFTP files
FROM debian:buster-slim as payloads
RUN apt update
RUN apt install unzip wget libguestfs-tools -y

COPY --from=legacy_syslinux /tftp/ /tftp

COPY ./scripts/* /
#RUN /extract_rpi.sh
RUN /fetch_gparted.sh
#RUN /extract_xubuntu1804_i386.sh
RUN /extract_ubcd.sh
RUN /fetch_clonezilla.sh #Beware: this link is rate limited to 10 download/week

FROM debian:buster-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

# Install dependencies
ENV DEBIAN_FRONTEND noninteractive
RUN apt -qq update --fix-missing -y && \
    apt install -y --no-install-recommends locales ca-certificates

# Support UTF-8
ADD locale.gen /etc/
RUN /usr/sbin/locale-gen && touch /etc/dnsmasq.conf
ENV LANG=en_US.utf8
ENV LC_ALL=en_US.UTF-8

COPY --from=payloads /tftp/ /tftp

#COPY --from=elv13/docker-piinitramfs /firmware-master/boot/ /tftp/pi_minimal/

#CMD /run.sh
