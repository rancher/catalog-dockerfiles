#!/bin/bash

set -e

while [ ! -f "/var/lib/zookeeper/myid" ]; do
    sleep 1
done

exec /opt/zookeeper/bin/zkServer.sh start-foreground
