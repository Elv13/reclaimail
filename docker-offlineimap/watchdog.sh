#!/bin/bash

while true; do
    sleep 30
    let delay=$(date +%s)-$(cat /tmp/ping)

    if [ "$delay" -gt 150 ]; then
        #TODO kill it
        echo RESTARTING | nc -w0 -Uu ~/GMail/query.socket
    else
        echo OK | nc -w0 -Uu ~/GMail/query.socket
    fi
done
