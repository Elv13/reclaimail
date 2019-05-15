#! /bin/sh

alias offlineimap="/home/offlineimap/offlineimap/offlineimap.py"

sed -i "s/YOUR_EMAIL/$EMAIL/" /home/offlineimap/.offlineimaprc
sed -i "s/YOUR_CLIENT_ID/$CLIENT_ID/" /home/offlineimap/.offlineimaprc
sed -i "s=YOUR_SECRET=$SECRET=" /home/offlineimap/.offlineimaprc
sed -i "s=YOUR_CLIENT_SECRET=$CLIENT_SECRET=" /home/offlineimap/.offlineimaprc

if [ ! -e '~/.offlineimap' ]; then
    mkdir -p /home/offlineimap/GMail/.offlineimap
    ln -s /home/offlineimap/GMail/.offlineimap ~
fi

mkdir -p /home/offlineimap/Mail/Mutt
ln -s /home/offlineimap/Mail/Mutt ~/

# Backup the offlineimaprc
cp /home/offlineimap/.offlineimaprc /home/offlineimap/.offlineimaprc.back

~/watchdog.sh &

while true; do
    # offlineimap crashes all the time, always refresh the damn token
    ACCESS_TOKEN=$(python2 ~/oauth2.py  --user=$EMAIL \
        --client_id=$CLIENT_ID \
        --client_secret=$CLIENT_SECRET \
        --refresh_token=$SECRET --quiet
    )

    sed -i "s/YOUR_ACCESS_TOKEN/$ACCESS_TOKEN/" /home/offlineimap/.offlineimaprc

    /home/offlineimap/offlineimap-next/offlineimap.py \
         -c /home/offlineimap/.offlineimaprc

    cp /home/offlineimap/.offlineimaprc.back /home/offlineimap/.offlineimaprc
done
