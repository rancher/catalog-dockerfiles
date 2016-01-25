#!/bin/bash

SWARM_ARGS=""
if [ -n "${JENKINS_USER}" ]; then
    SWARM_ARGS="${SWARM_ARGS} -username ${JENKINS_USER}"
fi

if [ -n "${JENKINS_PASS}" ]; then
    SWARM_ARGS="${SWARM_ARGS} -passwordEnvVariable JENKINS_PASS"
fi

if [ -n "${SWARM_EXECUTORS}" ]; then
    SWARM_ARGS="${SWARM_ARGS} -executors ${SWARM_EXECUTORS}"
fi

exec java -jar /usr/share/jenkins/swarm-client-${SWARM_CLIENT_VERSION}.jar -fsroot /var/jenkins_home ${SWARM_ARGS} -master http://jenkins-primary:${JENKINS_PORT:-8080}
