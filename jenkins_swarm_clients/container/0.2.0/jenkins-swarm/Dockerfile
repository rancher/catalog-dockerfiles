FROM jenkins:1.625.3

USER root

RUN apt-get update && apt-get install -y ca-certificates libapparmor-dev
ADD ./run.sh /run.sh

ENV SWARM_CLIENT_VERSION 2.0
ADD http://maven.jenkins-ci.org/content/repositories/releases/org/jenkins-ci/plugins/swarm-client/${SWARM_CLIENT_VERSION}/swarm-client-${SWARM_CLIENT_VERSION}-jar-with-dependencies.jar /usr/share/jenkins/swarm-client-${SWARM_CLIENT_VERSION}.jar
RUN chmod 644 /usr/share/jenkins/swarm-client-${SWARM_CLIENT_VERSION}.jar
RUN curl -s -L https://get.docker.com/builds/Linux/x86_64/docker-1.9.1 > /usr/bin/docker; chmod +x /usr/bin/docker

USER jenkins
WORKDIR /var/jenkins_home

ENTRYPOINT ["/run.sh"]
