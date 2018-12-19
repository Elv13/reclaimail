#! /bin/sh

#sed -i "s/YOUR_EMAIL/$EMAIL/" /home/offlineimap/.offlineimaprc
#sed -i "s/YOUR_CLIENT_ID/$CLIENT_ID/" /home/offlineimap/.offlineimaprc
#sed -i "s/YOUR_ACCESS_TOKEN/$ACCESS_TOKEN/" /home/offlineimap/.offlineimaprc
#sed -i "s=YOUR_SECRET=$SECRET=" /home/offlineimap/.offlineimaprc

#if [ ! -e '~/.offlineimap' ]; then
#    mkdir -p /home/offlineimap/GMail/.offlineimap
#    ln -s /home/offlineimap/GMail/.offlineimap ~
#fi

#mkdir -p /home/offlineimap/GMail/Mutt
#ln -s /home/offlineimap/GMail/Mutt ~/

notmuch new

echo "Adding KDE tags"
notmuch tag +KDE -- 'from:*@kde.org'
notmuch tag +KDE -- 'cc:*@kde.org'

echo "Adding GitHub tags"
notmuch tag +GitHub -- 'from:*github.com'
notmuch tag +GitHub -- 'from:*@github.com'
notmuch tag +GitHub -- 'from:notifications@github.com'

echo "Adding Awesome tags"
notmuch tag +Awesome -- 'subject:[awesomeWM/awesome]*'
notmuch tag +Awesome -- 'from:awesome@noreply.github.com' -- 'to:awesome@noreply.github.com'
notmuch tag +Awesome -- 'from:awesome@noreply.github.com'
notmuch tag +Awesome -- 'to:awesome@noreply.github.com'
notmuch tag +Awesome -- 'to:awesomeWM/awesome'
notmuch tag +Awesome -- 'from:@naquadah.org'
notmuch tag +Awesome -- 'from:*@naquadah.org'

echo "Adding Voicemail tags"
notmuch tag +Voicemail -- 'to:elv1313+voicemail@gmail.com'
