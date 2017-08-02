FROM alpine:3.3

WORKDIR /opt/rancher
ENV PATH $PATH:/opt/rancher

RUN \
  apk add --update bash ca-certificates && \
  rm -rf /var/cache/apk/* && \
  wget -q -O /opt/rancher/giddyup https://github.com/cloudnautique/giddyup/releases/download/v0.13.0/giddyup && \
  chmod +x /opt/rancher/giddyup

RUN \
  wget -q -O - https://github.com/coreos/etcd/releases/download/v2.3.7/etcd-v2.3.7-linux-amd64.tar.gz | tar xzf - -C /tmp && \
  mv /tmp/etcd-*/etcd /opt/rancher/etcd && \
  mv /tmp/etcd-*/etcdctl /opt/rancher/etcdctl && \
  rm -rf /tmp/etcd-* && rm -f /etcd-*.tar.gz

ADD etcdwrapper run.sh disaster delete /opt/rancher/

ENTRYPOINT ["/opt/rancher/run.sh"]
CMD ["node"]
