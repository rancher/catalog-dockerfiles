FROM rancher/confd-base:0.11.0-dev-rancher

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

VOLUME /etc/nginx/conf.d
VOLUME /etc/nginx/access

ENTRYPOINT ["/confd"]
CMD []
