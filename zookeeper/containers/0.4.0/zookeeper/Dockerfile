FROM alpine:3.3

RUN \
  apk update && \
  apk add --update bash curl openjdk8-jre && \
  rm -rf /var/cache/apk/*

RUN \
  curl -L https://github.com/kelseyhightower/confd/releases/download/v0.11.0/confd-0.11.0-linux-amd64 -o /usr/local/bin/confd && \
  chmod +x /usr/local/bin/confd

RUN \
  mkdir -p /opt && \
  curl -L https://dist.apache.org/repos/dist/release/zookeeper/zookeeper-3.4.8/zookeeper-3.4.8.tar.gz | tar xzf - -C /opt && \
  mv /opt/zookeeper-3.4.8 /opt/zookeeper
  
VOLUME ["/data"]

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

ADD run.sh /run.sh

ENTRYPOINT ["/run.sh"]
