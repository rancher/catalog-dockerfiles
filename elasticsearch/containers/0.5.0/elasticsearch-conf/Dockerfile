FROM busybox

ADD https://github.com/kelseyhightower/confd/releases/download/v0.11.0/confd-0.11.0-linux-amd64 /confd
RUN chmod +x /confd

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates
ADD ./run.sh /run.sh
ADD ./dockerentry.sh /dockerentry.sh

VOLUME /data/confd
VOLUME /opt/rancher/bin
VOLUME /usr/share/elasticsearch/config

ENTRYPOINT ["/dockerentry.sh"]
CMD ["--backend", "rancher", "--prefix", "/2015-07-25"]
