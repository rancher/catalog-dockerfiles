#FROM nrvale0/drone-debug:0.5
FROM alpine:3.4

LABEL vendor="Rancher Labs, Inc." \
	com.rancher.version="0.5" \
	com.rancher.repo="https://github.com/rancher/catalog-dockerfiles"

ENV GIDDYUP_VERSION='v0.14.0' CONFD_VERSION='v0.11.0'

RUN apk add --update bash && rm -rf /var/cache/apk/*

ADD ./confd/ /etc/confd/

ADD "https://github.com/cloudnautique/giddyup/releases/download/${GIDDYUP_VERSION}/giddyup /giddyup"
ADD "https://github.com/rancher/confd/releases/download/${CONFD_VERSION/confd-${CONFD_VERSION}-amd64 /confd"
ADD /scripts/*.sh /opt/rancher/scripts/

RUN chmod +x /confd /giddyup /opt/rancher/scripts/*

ENTRYPOINT ["/opt/rancher/scripts/rancher_drone-config_entrypoint.sh", "server"]

ADD Dockerfile /opt/rancher/
