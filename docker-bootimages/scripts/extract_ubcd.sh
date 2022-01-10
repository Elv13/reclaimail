#!/bin/sh
wget http://ftp.rnl.tecnico.ulisboa.pt/pub/UBCD/ubcd539.iso

mkdir -p /tftp/ubcd

guestfish << EOF
echo add
add-ro ubcd539.iso
echo run
run
echo mount
mount /dev/sda /
echo copy
copy-out /ubcd /tftp/
EOF


