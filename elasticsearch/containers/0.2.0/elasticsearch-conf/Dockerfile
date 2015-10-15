FROM rancher/confd-base:0.11.0-dev-rancher

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

VOLUME /usr/share/elasticsearch/config
VOLUME /data/confd

ENTRYPOINT ["/confd"]
CMD ["--backend", "rancher", "--prefix", "/2015-07-25"]
