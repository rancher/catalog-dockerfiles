FROM scratch

ADD ./confd-0.10.0-linux-amd64 /confd
ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates
VOLUME /etc/logstash

ENTRYPOINT ["/confd"]
CMD []
