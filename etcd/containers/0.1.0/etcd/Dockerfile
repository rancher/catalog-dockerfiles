FROM alpine:3.2

RUN apk add --update bash curl ca-certificates && rm -rf /var/cache/apk/*
ADD ./run.sh /opt/rancher/run.sh
ADD https://github.com/coreos/etcd/releases/download/v2.2.1/etcd-v2.2.1-linux-amd64.tar.gz /etcd-v2.2.1-linux-amd64.tar.gz
RUN tar -xzvf /etcd-*.tar.gz -C /tmp && \
    mv /tmp/etcd-*/etcd /etcd && \
    rm -rf /tmp/etcd-* && rm -f /etcd-*.tar.gz

VOLUME "/opt/rancher"

CMD ["/bin/sleep", "5"]
