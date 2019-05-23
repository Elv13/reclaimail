#!/bin/bash

docker run --privileged --net host --device=/dev/loop-control:/dev/loop-control\
    -v /mnt/sdc1/ISO:/ISO -v persist:/persist -t elv13/routing
