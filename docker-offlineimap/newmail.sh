#!/bin/bash

echo NEW | nc -w0 -Uu ~/GMail/query.socket

date +%s > /tmp/ping
