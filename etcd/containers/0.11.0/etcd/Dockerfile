FROM alpine:3.3

RUN \
  apk add --update bash ca-certificates && \
  rm -rf /var/cache/apk/* && \
  wget -q -O /usr/local/bin/giddyup https://github.com/cloudnautique/giddyup/releases/download/v0.13.0/giddyup && \
  chmod +x /usr/local/bin/giddyup

RUN \
  wget -q -O - https://github.com/coreos/etcd/releases/download/v2.3.7/etcd-v2.3.7-linux-amd64.tar.gz | tar xzf - -C /tmp && \
  mv /tmp/etcd-*/etcd /usr/local/bin/etcd && \
  mv /tmp/etcd-*/etcdctl /usr/local/bin/etcdctl && \
  rm -rf /tmp/etcd-* && rm -f /etcd-*.tar.gz

ADD etcdhc /usr/bin/etcdhc
ADD run.sh /run.sh
ADD disaster /usr/bin/disaster

ENTRYPOINT ["/run.sh"]
CMD ["node"]
