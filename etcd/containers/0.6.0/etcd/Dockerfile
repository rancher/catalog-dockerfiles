FROM alpine:3.3

RUN \
  apk add --update bash ca-certificates && \
  rm -rf /var/cache/apk/* && \
  wget -q -O /usr/local/bin/giddyup https://github.com/cloudnautique/giddyup/releases/download/v0.11.0/giddyup && \
  chmod +x /usr/local/bin/giddyup

RUN \
  wget -q -O - https://github.com/coreos/etcd/releases/download/v2.3.6/etcd-v2.3.6-linux-amd64.tar.gz | tar xzf - -C /tmp && \
  mv /tmp/etcd-*/etcd /usr/local/bin/etcd && \
  mv /tmp/etcd-*/etcdctl /usr/local/bin/etcdctl && \
  rm -rf /tmp/etcd-* && rm -f /etcd-*.tar.gz

ADD run.sh /run.sh

ENTRYPOINT ["/run.sh"]
CMD ["node"]
