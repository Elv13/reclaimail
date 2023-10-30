#!/bin/bash

# Enable non-free

mv /etc/apt/sources.list /tmp/
IFS=$'\n'

for line in $(cat /tmp/sources.list); do
    echo $line contrib non-free >> /etc/apt/sources.list
done



export DEBIAN_FRONTEND=noninteractive
echo Installing $(wc -w /assets/packages.txt) packages!
echo | apt-get update
echo | apt-get upgrade -y

for PACK in $(cat /assets/packages.txt); do
    # Allow individual package to fail without making the whole thing fail
    apt-get install -y --no-install-recommends $PACK || echo "\e[31m * $PACK \e[m" >> /tmp/failed
done

if [ -e /tmp/failed ]; then
    echo "INSTALL FAILURE:"
    cat /tmp/failed
fi
