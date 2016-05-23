#!/bin/sh -e
###############################################################################
METADATA_HOST=rancher-metadata.rancher.internal
METADATA_VERSION=2015-12-19
METADATA=$METADATA_HOST/$METADATA_VERSION
metadata() { echo $(curl -s $METADATA/$1); }
get_containers() { echo $(metadata self/service/containers); }
num_containers() { echo $(get_containers | tr ' ' '\n' | wc -l); }
###############################################################################

CONFD_INTERVAL=${CONFD_INTERVAL:-60}
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

# Write static configuration
sed -i "s/\$ZK_TICK_TIME/$ZK_TICK_TIME/g" /etc/confd/templates/zoo.cfg.tmpl
sed -i "s/\$ZK_INIT_LIMIT/$ZK_INIT_LIMIT/g" /etc/confd/templates/zoo.cfg.tmpl
sed -i "s/\$ZK_SYNC_LIMIT/$ZK_SYNC_LIMIT/g" /etc/confd/templates/zoo.cfg.tmpl
sed -i "s/\$ZK_MAX_CLIENT_CXNS/$ZK_MAX_CLIENT_CXNS/g" /etc/confd/templates/zoo.cfg.tmpl

confd --backend rancher --prefix /2015-07-25 &

# Wait for confd to create initial config files
while [ ! -f /opt/zookeeper/conf/zoo.cfg ] || [ ! -f /data/myid ]; do
  sleep 1
done

exec /opt/zookeeper/bin/zkServer.sh start-foreground
