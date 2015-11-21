FROM alpine:3.2

RUN apk add --update bash curl && rm -rf /var/cache/apk/*

ADD ./run /
ADD ./start_galera /

# Confd
ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

ADD https://github.com/rancher/confd/releases/download/0.11.0-dev-rancher/confd-0.11.0-dev-rancher-linux-amd64 /confd
RUN chmod +x /confd

entrypoint ["/run"]
