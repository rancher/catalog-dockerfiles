FROM rancher/hadoop-base:v0.3.5

ADD https://github.com/rancher/confd/releases/download/0.11.0-dev-rancher/confd-0.11.0-dev-rancher-linux-amd64 /confd
RUN chmod +x /confd

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

VOLUME ["/etc/hadoop"]

ENTRYPOINT ["/confd"]
CMD ["--interval", "10", "--backend", "rancher", "--prefix", "/2015-07-25"]
