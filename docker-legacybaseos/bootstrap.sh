#!/bin/bash

export BASE=/mnt/endgame/

export LD_LIBRARY_PATH=/lib:/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu:/lib:${BASE}/usr/lib/x86_64-linux-gnu/libfakeroot:${BASE}/usr/local/lib:${BASE}/lib/x86_64-linux-gnu:${BASE}/usr/lib/x86_64-linux-gnu:${BASE}/usr/lib:${BASE}/lib:${BASE}/lib/systemd/

function fake() {
    cp /usr/bin/qemu-x86_64-static ${BASE}/qemu-${ARCH}-static
    fakechroot --env=/env.sh fakeroot chroot $BASE /qemu-${ARCH}-static $@
    rm ${BASE}/qemu-x86_64-static
}

# Hack to work around some fakeroot bugs
#cp /clean.sh $BASE/clean.sh
#fake /clean.sh
#rm $BASE/clean.sh

fake $@
