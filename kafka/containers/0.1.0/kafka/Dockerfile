FROM centos:7

RUN yum install -y net-tools java-1.8.0-openjdk

ADD http://mirror.switch.ch/mirror/apache/dist/kafka/0.8.2.2/kafka_2.11-0.8.2.2.tgz /opt/
RUN cd /opt && tar xf *.tgz && rm -f *.tgz
RUN mv /opt/kafka* /opt/kafka

ADD run.sh /run.sh

EXPOSE 9092

VOLUME ["/opt/kafka/conf.d"]

WORKDIR /opt/kafka

ENTRYPOINT ["/run.sh"]
