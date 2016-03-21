FROM centos:7

RUN yum install -y wget && \
    wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm && \
    rpm -ivh epel-release-7-5.noarch.rpm && \
    wget -P /etc/yum.repos.d http://download.gluster.org/pub/gluster/glusterfs/LATEST/EPEL.repo/glusterfs-epel.repo && \
    yum install -y glusterfs-server glusterfs glusterfs-fuse jq curl && \
    mv /var/lib/glusterd/hooks/1/set/post/S30samba-set.sh /var/lib/glusterd/hooks/1/set/post/dS30samba-set.sh && \
    mv /var/lib/glusterd/hooks/1/start/post/S30samba-start.sh /var/lib/glusterd/hooks/1/start/post/dS30samba-start.sh && \
    mv /var/lib/glusterd/hooks/1/stop/pre/S30samba-stop.sh /var/lib/glusterd/hooks/1/stop/pre/dS30samba-stop.sh

VOLUME ["/data/glusterfs/brick1"]

ADD ./*.sh /opt/rancher/

EXPOSE 24007
EXPOSE 24007/udp
EXPOSE 24008
EXPOSE 24008/udp
EXPOSE 49152

# Add Giddyup v0.8.0
ADD giddyup /usr/bin/giddyup
RUN chmod +x /usr/bin/giddyup
