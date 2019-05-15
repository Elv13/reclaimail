FROM debian:stretch-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN cat /etc/apt/sources.list | sed 's/deb /deb-src /' >> /etc/apt/sources.list
RUN apt-get -qq update --fix-missing
RUN apt-get install -y --no-install-recommends\
    bash netcat-openbsd wget unzip \
    python-requests-oauthlib  python-oauthlib ca-certificates

RUN apt-get build-dep offlineimap -y

RUN useradd -m offlineimap
WORKDIR /home/offlineimap/

ADD offlineimaprc /home/offlineimap/.offlineimaprc
ADD *.py ./
ADD *.sh ./

RUN chown -R offlineimap:users /home/offlineimap
RUN chmod +x *.sh

USER offlineimap

# Avoids installing Git (to make the image smaller)
RUN wget http://github.com/OfflineIMAP/offlineimap/archive/next.zip && \
  unzip next.zip && rm next.zip

# Use exec mode so offlineimap can receive SIGUSR2
ENTRYPOINT ["/home/offlineimap/run.sh"]
