FROM alpine:3.2

RUN \
  apk add --update bash curl jq ca-certificates && \
  rm -rf /var/cache/apk/*

RUN \
  curl -L https://github.com/coreos/etcd/releases/download/v2.3.3/etcd-v2.3.3-linux-amd64.tar.gz | tar xzf - -C /tmp && \
  mv /tmp/etcd-*/etcd /usr/local/bin/etcd && \
  mv /tmp/etcd-*/etcdctl /usr/local/bin/etcdctl && \
  rm -rf /tmp/etcd-* && rm -f /etcd-*.tar.gz

ADD run.sh /run.sh

ENTRYPOINT ["/run.sh"]
CMD ["node"]
