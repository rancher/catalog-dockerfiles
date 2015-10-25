#!/bin/bash


if [ ! -f /usr/share/jenkins/rancher/plugins.txt ]; then
    sleep 1
else
    /usr/local/bin/plugins.sh /usr/share/jenkins/rancher/plugins.txt
fi

exec /bin/tini -- /usr/local/bin/jenkins.sh
