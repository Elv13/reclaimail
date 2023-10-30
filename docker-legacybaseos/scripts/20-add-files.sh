#!/bin/bash

# Note, this doesn't preserve permissions or owners
find /filesystem -type d | xargs mkdir -p
cp /filesystem/* / -r
