FROM rancher/confd-base:v0.1.0

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates
VOLUME /etc/logstash
VOLUME /opt/logstash/patterns

ENTRYPOINT ["/confd"]
CMD []
