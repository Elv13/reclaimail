#!/bin/bash

echo BEGIN_SYNC | nc -w0 -Uu ~/GMail/query.socket

date +%s > /tmp/ping
