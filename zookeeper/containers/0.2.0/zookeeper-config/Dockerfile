FROM rancher/confd-base:0.11.0-dev-rancher

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

VOLUME ["/var/lib/zookeeper", "/opt/zookeeper/conf/", "/opt/rancher"]

ENTRYPOINT ["/confd"]
CMD ["--interval", "30", "--backend", "rancher", "--prefix", "/2015-07-25"]
