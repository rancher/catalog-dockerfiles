FROM alpine:3.3

RUN \
  apk update && \
  apk add openjdk8 curl && \
  curl -L https://dist.apache.org/repos/dist/release/zookeeper/zookeeper-3.4.8/zookeeper-3.4.8.tar.gz -o /zookeeper.tar.gz && \
  apk del curl && \
  tar -zxvf /zookeeper.tar.gz && \
  rm -rf /zookeeper.tar.gz && \
  mv /zookeeper-* /zookeeper && \
  rm -rf /var/cache/apk/*

ADD zoo.cfg /zookeeper/conf/zoo.cfg
ADD zk* /usr/local/bin/
EXPOSE 2181
VOLUME ["/zookeeper/data"]
ENTRYPOINT ["zk-server"]
