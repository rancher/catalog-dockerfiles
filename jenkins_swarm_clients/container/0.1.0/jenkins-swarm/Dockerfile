FROM jenkins:1.625.1

USER root

RUN apt-get update && apt-get install -y libapparmor-dev

ENV SWARM_CLIENT_VERSION 2.0
ADD http://maven.jenkins-ci.org/content/repositories/releases/org/jenkins-ci/plugins/swarm-client/${SWARM_CLIENT_VERSION}/swarm-client-${SWARM_CLIENT_VERSION}-jar-with-dependencies.jar /usr/share/jenkins/swarm-client-${SWARM_CLIENT_VERSION}.jar
RUN chmod 644 /usr/share/jenkins/swarm-client-${SWARM_CLIENT_VERSION}.jar

ADD ./run.sh /run.sh

USER jenkins
WORKDIR /var/jenkins_home

ENTRYPOINT ["/run.sh"]
