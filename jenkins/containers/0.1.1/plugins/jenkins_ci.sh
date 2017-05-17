#!/bin/bash


while [ ! -f /usr/share/jenkins/rancher/plugins.txt ]; do
    sleep 1
done

/usr/local/bin/install-plugins.sh $(cat /usr/share/jenkins/rancher/plugins.txt | tr '\n' ' ')
exec /bin/tini -- /usr/local/bin/jenkins.sh
