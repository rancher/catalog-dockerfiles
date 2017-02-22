#!/bin/bash


while [ ! -f /usr/share/jenkins/rancher/plugins.txt ]; do
    sleep 1
done

/usr/local/bin/install-plugins.sh /usr/share/jenkins/rancher/plugins.txt
exec /bin/tini -- /usr/local/bin/jenkins.sh
