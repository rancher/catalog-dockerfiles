FROM rancher/confd-base:0.11.0-dev-rancher

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

VOLUME ["/opt/kafka/conf.d"]

ENTRYPOINT ["/confd"]
CMD ["--interval", "30", "--backend", "rancher", "--prefix", "/latest"]
