FROM debian:bullseye-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

ENV ARCH=x86_64
ENV DEBARCH=amd64
ENV DEB_RELEASE=bullseye
ENV DEBIAN_FRONTEND noninteractive
ENV HOSTNAME=reclaim-baseos
ENV PLATFORM=x86_64-efi

RUN apt -qq update --fix-missing -y
RUN apt install debootstrap fakechroot fakeroot xfsprogs parted \
                udev qemu-user-static libguestfs0 libguestfs-tools \
                qemu-system-x86 python3-guestfs -y

#RUN truncate -s 8G fileserver.img
#RUN parted --script ./fileserver.img mklabel gpt mkpart primary 1MiB 7GiB
#RUN losetup --offset $((512*2048)) --sizelimit $((512*25165824)) --show --find ./fileserver.img

RUN mkdir -p /mnt/endgame
RUN debootstrap --arch=${DEBARCH} ${DEB_RELEASE} /mnt/endgame

#RUN for UUID in $(find  /dev/disk/by-uuid/ -maxdepth 1); do\
#    if [ "$(readlink -f $UUID)" == "/dev/sdb1" ]; then\
#        sed -i "s/ROOT_UUID/$(basename $UUID)/" /etc/fstab;\
#    fi;\
#done

ADD bootstrap.sh env.sh clean.sh createimg.py /
ADD assets assets/
ADD scripts scripts/
ADD filesystem filesystem/
RUN /bootstrap.sh bash -c 'echo $HOSTNAME > /etc/hostname'

# Download, but don't install since installing a kernel in a fakeroot
# explodes in funny ways, thanks systemd!
RUN /bootstrap.sh /usr/bin/apt update && \
    cat /assets/packages.txt | xargs /bootstrap.sh /usr/bin/apt install systemd libsystemd0 kmod psmisc \
        grub-pc linux-image-amd64 xfsprogs -y --no-install-recommends --download-only

#RUN /bootstrap.sh sed -e ':loop' -e 's/hd1/hd0/g' -e 't loop' -i /boot/grub/grub.cfg
#RUN /bootstrap.sh sed -e ':loop' -e 's/ ro / rw /g' -e 't loop' -i /boot/grub/grub.cfg

