FROM debian:stretch
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN cat /etc/apt/sources.list | sed 's/deb /deb-src /' >> /etc/apt/sources.list
RUN apt-get -qq update --fix-missing
RUN apt-get install -y bash git
RUN apt-get install -y wget nano python-requests-oauthlib
RUN apt-get install -y python-oauthlib ca-certificates
RUN apt-get build-dep offlineimap -y

RUN useradd -m offlineimap
ADD run.sh /home/offlineimap/run.sh
RUN chmod 755 /home/offlineimap/run.sh

RUN chown -R offlineimap:users /home/offlineimap/

ADD offlineimaprc /home/offlineimap/.offlineimaprc
RUN chown offlineimap:offlineimap /home/offlineimap/.offlineimaprc

USER offlineimap

RUN cd /home/offlineimap/ && git clone https://github.com/OfflineIMAP/offlineimap.git
RUN cd /home/offlineimap/offlineimap && git checkout next

ADD oauth2.py /home/offlineimap/

# Use exec mode so offlineimap can receive SIGUSR2
ENTRYPOINT ["/home/offlineimap/run.sh"]
