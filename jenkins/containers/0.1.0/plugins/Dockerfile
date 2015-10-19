FROM rancher/confd-base:0.11.0-dev-rancher

ADD ./conf.d /etc/confd/conf.d
ADD ./templates /etc/confd/templates
ADD ./jenkins_ci.sh /usr/share/jenkins/rancher/jenkins.sh
VOLUME /usr/share/jenkins/rancher

ENTRYPOINT ["/confd"]

CMD ["--backend", "rancher", "--prefix", "/2015-07-25"]
