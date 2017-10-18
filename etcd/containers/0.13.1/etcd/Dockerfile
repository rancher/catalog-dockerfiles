FROM rancher/agent-base:v0.3.0

WORKDIR /opt/rancher
ENV PATH $PATH:/opt/rancher

RUN \
  apt-get update && apt-get install -y ca-certificates wget && \
  apt-get clean && \
  wget -q -O /opt/rancher/giddyup https://github.com/rancher/giddyup/releases/download/v0.18.0/giddyup && \
  chmod +x /opt/rancher/giddyup

RUN \
  wget -q -O - https://github.com/coreos/etcd/releases/download/v2.3.7/etcd-v2.3.7-linux-amd64.tar.gz | tar xzf - -C /tmp && \
  mv /tmp/etcd-*/etcd /opt/rancher/etcd && \
  mv /tmp/etcd-*/etcdctl /opt/rancher/etcdctl && \
  rm -rf /tmp/etcd-* && rm -f /etcd-*.tar.gz

ADD etcdwrapper run.sh disaster delete /opt/rancher/

ENTRYPOINT ["/opt/rancher/run.sh"]
CMD ["node"]
