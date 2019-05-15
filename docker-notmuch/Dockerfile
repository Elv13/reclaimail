########################### BUILDER #############################

# Build LPEG for Luajit2, the version from `apt` segfaults because it
# is built for the wrong Lua.
FROM debian:stretch-slim as builder
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

RUN apt update --fix-missing -y && \
    apt install -y --no-install-recommends \
        wget gcc make libluajit-5.1-dev libc6-dev unzip ca-certificates

# Helps parse the emails "manually" for the elements notmuch doesn't
# support.
RUN wget http://www.inf.puc-rio.br/~roberto/lpeg/lpeg-1.0.2.tar.gz && \
    wget https://github.com/spc476/LPeg-Parsers/archive/master.zip && \
    tar -xpvf lpeg* && ln -s /usr/include/luajit-2.0/ lua && \
    unzip master.zip && rm master.zip

# Compile LPEG and merge it with LPeg-Parsers
RUN cd lpeg-1.0.2 && make && cp *.so *.lua /LPeg-Parsers-master

########################### RUNNER #############################

FROM debian:stretch-slim
MAINTAINER Emmanuel Lepage Vallee <elv1313+bugs@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -qq update --fix-missing -y && \
    apt-get install -y --no-install-recommends notmuch luajit libxml2

RUN useradd -m notmuch
ADD run.sh /home/notmuch/run.sh

RUN chown -R notmuch:users /home/notmuch/

ADD notmuch-config /home/notmuch/.notmuch-config
RUN chown notmuch:notmuch /home/notmuch/.notmuch-config

ADD notmuchlua /home/notmuch/notmuchlua
ADD hooks /home/notmuch/hooks

# Using the builder avoids having to install unzip and wget
COPY --from=builder /LPeg-Parsers-master /home/notmuch/LPeg-Parsers-master

USER notmuch

# Go to the filter page of GMail, press "export" and put the resulting
# file in the docker-notmuch directory (of the builder host)
ADD mailFilters.xml /home/notmuch

# Use exec mode so notmuch can receive SIGUSR2
ENTRYPOINT ["/home/notmuch/run.sh"]
