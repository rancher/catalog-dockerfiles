FROM rancher/confd-base:v0.1.0

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

VOLUME /etc/nginx/conf.d
VOLUME /etc/nginx/access

ENTRYPOINT ["/confd"]
CMD []
