#!/bin/bash

echo Start cleaning symlinks
find /usr/ -type l \
    | xargs -i bash -c 'export LNK=$(readlink -f {}); rm {} && ln -s ${LNK} {}'
echo Finished cleaning symlinks
