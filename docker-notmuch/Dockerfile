FROM debian:stretch
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -qq update --fix-missing -y
RUN apt-get install -y bash wget nano python-requests-oauthlib \
    notmuch ca-certificates --no-install-recommends

RUN useradd -m notmuch
ADD run.sh /home/notmuch/run.sh
RUN chmod 755 /home/notmuch/run.sh

RUN chown -R notmuch:users /home/notmuch/

ADD notmuch-config /home/notmuch/.notmuch-config
RUN chown notmuch:notmuch /home/notmuch/.notmuch-config

USER notmuch

# Use exec mode so notmuch can receive SIGUSR2
ENTRYPOINT ["/home/notmuch/run.sh"]
