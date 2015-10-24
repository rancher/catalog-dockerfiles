FROM debian:jessie

RUN apt-get update && \
    apt-get install -y --no-install-recommends openjdk-7-jre-headless

ADD http://mirror.metrocast.net/apache/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz /opt/
RUN cd /opt && \
    tar -zxvf zookeeper-3.4.6.tar.gz && \
    mv zookeeper-3.4.6 zookeeper && \
    rm -rf ./zookeeper-*tar.gz && \
    mkdir -p /var/lib/zookeeper

ADD entry.sh /entry.sh

WORKDIR /opt/zookeeper
EXPOSE 2181 2888 3888
VOLUME ["/var/lib/zookeeper", "/opt/zookeeper/conf", "/tmp/zookeeper"]

ENTRYPOINT ["/entry.sh"]
