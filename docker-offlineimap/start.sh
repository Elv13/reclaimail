#!/bin/bash

if [ "$4" == "" ]; then
    echo 'Usage: <email> <client_id> <client_secret> <refresh_token>'
    echo "==Fallback to user inputs=="
    echo
fi

if [ "$1" == "" ]; then
    echo 'E-Mail address:'
    read EMAIL
else
    EMAIL=$1
fi


if [ "$2" == "" ]; then
    echo 'Client ID (ends with apps.googleusercontent.com):'
    read CLIENT_ID
else
    CLIENT_ID=$2
fi

if [ "$3" == "" ]; then
    echo 'Client secret (short base64 string):'
    read CLIENT_SECRET
else
    CLIENT_SECRET=$3
fi

if [ "$4" == "" ]; then
    echo 'Refresh Token (longer base64 string):'
    read REFRESH_TOKEN
else
    REFRESH_TOKEN=$4
fi

if [ "$5" == "" ]; then
    echo 'Maildir path (empty directories are fine too):'
    read MAILDIR
else
    MAILDIR=$5
fi

if [ "$5" == "" ]; then
   echo next time use:
   echo ./start.sh $EMAIL $CLIENT_ID $CLIENT_SECRET $REFRESH_TOKEN $MAILDIR
fi

sudo docker run -ti -eSECRET=$REFRESH_TOKEN -eEMAIL=$EMAIL \
     -eCLIENT_ID=$CLIENT_ID -eCLIENT_SECRET=$CLIENT_SECRET\
     -v $MAILDIR:/home/offlineimap/GMail  elv13/offlineimap
