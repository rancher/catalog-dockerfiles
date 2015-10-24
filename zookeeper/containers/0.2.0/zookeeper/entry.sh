#!/bin/bash

set -e

run_zk()
{
    exec /opt/zookeeper/bin/zkServer.sh start-foreground
}

while [ ! -f "/var/lib/zookeeper/myid" ]; do
    sleep 1
done

if [ ! -f "/opt/rancher/startup.meta" ]; then
    sleep 1
else
    while [ "$(grep ^server /opt/zookeeper/conf/zoo.cfg|wc -l)" -lt "$(</opt/rancher/startup.meta)" ]; do
        sleep 1
    done
fi

run_zk
