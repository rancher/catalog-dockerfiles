FROM alpine:3.3

RUN \
  apk update && \
  apk add --update bash curl openjdk8-jre && \
  rm -rf /var/cache/apk/*

RUN \
  mkdir -p /opt && \
  curl -L https://dist.apache.org/repos/dist/release/zookeeper/zookeeper-3.4.8/zookeeper-3.4.8.tar.gz | tar xzf - -C /opt && \
  mv /opt/zookeeper-3.4.8 /opt/zookeeper
  
VOLUME ["/data", "/log"]

EXPOSE 2181

ADD zoo.cfg /opt/zookeeper/conf/zoo.cfg

ADD run.sh /run.sh

ENTRYPOINT ["/run.sh"]
