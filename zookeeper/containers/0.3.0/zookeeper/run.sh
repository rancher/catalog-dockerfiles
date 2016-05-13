#!/bin/sh -e
###############################################################################
METADATA_HOST=rancher-metadata.rancher.internal
METADATA_VERSION=2015-12-19
METADATA=$METADATA_HOST/$METADATA_VERSION
metadata() { echo $(curl -s $METADATA/$1); }
get_containers() { echo $(metadata self/service/containers); }
num_containers() { echo $(get_containers | tr ' ' '\n' | wc -l); }
service_index() { echo $(metadata self/container/service_index); }
container_primary_ip() { echo $(metadata self/service/containers/$1/primary_ip); }
container_service_index() { echo $(metadata self/service/containers/$1/service_index); }
###############################################################################

ZK_ENSEMBLE_SIZE=${ZK_ENSEMBLE_SIZE:-1}
ZK_TICK_TIME=${ZK_TICK_TIME:-2000}
ZK_INIT_LIMIT=${ZK_INIT_LIMIT:-10}
ZK_SYNC_LIMIT=${ZK_SYNC_LIMIT:-5}
ZK_MAX_CLIENT_CXNS=${ZK_MAX_CLIENT_CXNS:-60}

# Wait for all zookeeper nodes to be scheduled
while [ "$(num_containers)" != "$ZK_ENSEMBLE_SIZE" ]; do
  echo Found $(num_containers) of $ZK_ENSEMBLE_SIZE nodes
  sleep $ZK_ENSEMBLE_SIZE
done

# Write service id
service_index > /data/myid

# Write static configuration
sed -i "s/\$ZK_TICK_TIME/$ZK_TICK_TIME/g" /opt/zookeeper/conf/zoo.cfg
sed -i "s/\$ZK_INIT_LIMIT/$ZK_INIT_LIMIT/g" /opt/zookeeper/conf/zoo.cfg
sed -i "s/\$ZK_SYNC_LIMIT/$ZK_SYNC_LIMIT/g" /opt/zookeeper/conf/zoo.cfg
sed -i "s/\$ZK_MAX_CLIENT_CXNS/$ZK_MAX_CLIENT_CXNS/g" /opt/zookeeper/conf/zoo.cfg
for container in $(get_containers); do
  index=$(echo $container | tr '=' '\n' | head -1)
  service_index=$(container_service_index $index)
  ip=$(container_primary_ip $index)
  echo server.$service_index=$ip:2888:3888 >> /opt/zookeeper/conf/zoo.cfg
done

exec /opt/zookeeper/bin/zkServer.sh start-foreground
