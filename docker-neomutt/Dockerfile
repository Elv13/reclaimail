FROM debian:stretch-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

# Install dependencies
ENV DEBIAN_FRONTEND noninteractive
RUN sed 's/deb /deb-src /' /etc/apt/sources.list >> /etc/apt/sources.list
RUN apt -qq update --fix-missing -y
RUN apt build-dep mutt -y
RUN apt install -y --no-install-recommends \
    ca-certificates unzip wget lua5.3-dev libxml2-utils  locales luajit -y

# Support UTF-8
ADD locale.gen /etc/
RUN /usr/sbin/locale-gen
ENV LANG=en_US.utf8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color

# Avoid using root with externally mounted volume, it helps privilege
# escalation by playing with file permissions
RUN groupadd email && \
    useradd -m neomutt -G email && \
    chown -R neomutt:users /home/neomutt/

WORKDIR /home/neomutt/
USER neomutt

# Get NeoMutt
RUN wget https://github.com/neomutt/neomutt/archive/master.zip && \
  unzip master.zip && rm master.zip

# Build NeoMutt
RUN cd /home/neomutt/neomutt-master && ./configure --notmuch --lua && \
    make -j8

# Add the config
ADD --chown=neomutt:neomutt notmuch-config /home/neomutt/.notmuch-config
ADD --chown=neomutt:neomutt config/ /home/neomutt/.mutt/

# Use exec mode so neomutt can receive SIGUSR2
ENTRYPOINT ["/home/neomutt/neomutt-master/neomutt"]
