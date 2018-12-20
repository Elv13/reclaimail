FROM debian:stretch
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN cat /etc/apt/sources.list | sed 's/deb /deb-src /' >> /etc/apt/sources.list
RUN apt-get -qq update --fix-missing
RUN apt-get install -y bash git netcat-openbsd wget nano \
                       python-requests-oauthlib  python-oauthlib ca-certificates
RUN apt-get build-dep offlineimap -y

RUN useradd -m offlineimap
WORKDIR /home/offlineimap/

ADD offlineimaprc /home/offlineimap/.offlineimaprc
ADD *.py ./
ADD *.sh ./

RUN chown -R offlineimap:users /home/offlineimap
RUN chmod +x newmail.sh run.sh

USER offlineimap

RUN git clone https://github.com/OfflineIMAP/offlineimap.git --branch next

# Use exec mode so offlineimap can receive SIGUSR2
# ENTRYPOINT ["/home/offlineimap/run.sh"]
