#!/bin/bash

if [ "$1" == "" ]; then
    echo 'Maildir path (can be empty):'
    read MAILDIR
else
    MAILDIR=$1
fi

docker run -ti -v $MAILDIR:/home/notmuch/GMail elv13/notmuch
