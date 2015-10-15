FROM rancher/confd-base:v0.1.0

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

VOLUME /usr/share/elasticsearch/config
VOLUME /data/confd

ENTRYPOINT ["/confd"]
CMD []
