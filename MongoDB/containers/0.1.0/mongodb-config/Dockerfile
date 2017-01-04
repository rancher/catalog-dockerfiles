FROM alpine:3.1
MAINTAINER Hussein Galal

# install giddyup
RUN apk add -U curl \
    && mkdir -p /opt/rancher/bin \
    && curl -L https://github.com/cloudnautique/giddyup/releases/download/v0.14.0/giddyup -o /opt/rancher/bin/giddyup \
    && chmod u+x /opt/rancher/bin/*

ADD ./*.sh /opt/rancher/bin/
RUN chmod u+x /opt/rancher/bin/*.sh

VOLUME /opt/rancher/bin
