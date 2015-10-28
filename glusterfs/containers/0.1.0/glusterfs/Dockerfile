FROM centos:7

RUN yum install -y wget && \
    wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm && \
    rpm -ivh epel-release-7-5.noarch.rpm && \
    wget -P /etc/yum.repos.d http://download.gluster.org/pub/gluster/glusterfs/LATEST/CentOS/glusterfs-epel.repo && \
    yum install -y glusterfs-server glusterfs glusterfs-fuse jq curl

VOLUME ["/data/glusterfs/brick1"]

ADD ./*.sh /opt/rancher/

EXPOSE 24007
EXPOSE 24007/udp
EXPOSE 24008
EXPOSE 24008/udp

# One brick model
EXPOSE 49152

CMD ["glusterd", "-p", "/var/run/glusterd.pid", "-N"]
