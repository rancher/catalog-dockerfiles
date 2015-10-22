FROM rancher/confd-base:0.11.0-dev-rancher

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates
ADD ./run.sh /opt/rancher/bin/

VOLUME /usr/share/elasticsearch/config
VOLUME /data/confd
VOLUME /opt/rancher/bin

ENTRYPOINT ["/confd"]
CMD ["--backend", "rancher", "--prefix", "/2015-07-25"]
