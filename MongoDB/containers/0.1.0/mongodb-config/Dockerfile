FROM alpine:3.1
MAINTAINER Hussein Galal

ADD ./*.sh /opt/rancher/bin/
RUN chmod u+x /opt/rancher/bin/*.sh

# install dig and jq
RUN apk add -U alpine-sdk \
    && curl ftp://ftp.isc.org/isc/bind9/9.10.2/bind-9.10.2.tar.gz|tar -xzv \
    && cd bind-9.10.2 \
    && CFLAGS="-static" ./configure --without-openssl --disable-symtable \
    && make \
    && cp ./bin/dig/dig /opt/rancher/bin/ \
    && curl -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o /opt/rancher/bin/jq \
    && chmod u+x /opt/rancher/bin/jq \
    && apk del alpine-sdk \
    && rm -rf /var/cache/apk/* \
    && rm -rf /bind-9.10.2/

VOLUME /opt/rancher/bin
