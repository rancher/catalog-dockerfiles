FROM alpine:3.1
MAINTAINER Hussein Galal

ADD ./*.sh /opt/rancher/bin/
RUN chmod u+x /opt/rancher/bin/*.sh

# compile and install dig
RUN apk add -U alpine-sdk \
    && curl ftp://ftp.isc.org/isc/bind9/9.10.2/bind-9.10.2.tar.gz|tar -xzv \
    && cd bind-9.10.2 \
    && CFLAGS="-static" ./configure --without-openssl --disable-symtable \
    && make \
    && cp ./bin/dig/dig /opt/rancher/bin/ 

# download jq
RUN curl -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -o /opt/rancher/bin/jq \
    && chmod u+x /opt/rancher/bin/jq 

# cleanup
RUN apk del alpine-sdk
RUN rm -rf /var/cache/apk/*
RUN rm -rf /bind-9.10.2/

VOLUME /opt/rancher/bin
