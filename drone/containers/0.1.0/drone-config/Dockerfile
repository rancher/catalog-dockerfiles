FROM alpine:3.2

RUN apk add --update bash && rm -rf /var/cache/apk/*

# Confd
ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates

ADD https://github.com/cloudnautique/giddyup/releases/download/v0.7.0/giddyup /giddyup
ADD https://github.com/rancher/confd/releases/download/0.11.0-dev-rancher/confd-0.11.0-dev-rancher-linux-amd64 /confd
ADD https://github.com/cloudnautique/dynamic-drone-nodes/releases/download/v0.1.1/dynamic-drone-nodes /dynamic-drone-nodes
RUN chmod +x /confd /giddyup /dynamic-drone-nodes

ADD ./*.sh /

ENTRYPOINT ["/run.sh"]
