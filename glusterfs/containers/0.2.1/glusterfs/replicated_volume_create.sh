#!/bin/bash

. /opt/rancher/common.sh

set -e

STRINGIFY_OPTS=
IP_METHOD=get_container_primary_ip
if [ "$1" = "host" ]; then
    STRINGIFY_OPTS="--use-agent-names"
    IP_METHOD=get_host_name
fi

echo "Waiting for all containers to come up..."
/giddyup service wait scale --timeout=1200
echo "Containers are coming up..."

ALLMETA=$(curl -s -H 'Accept: application/json' ${META_URL})
VOLUME_NAME=$(echo ${ALLMETA} | jq -r '.self.service.metadata.volume_name')
BRICK_PATH="/data/glusterfs/brick1"
VOLUME_PATH="${BRICK_PATH}/${VOLUME_NAME}"
REPLICA_COUNT=$(/giddyup service scale)

if [ ! -f ${VOLUME_PATH} ]; then
    mkdir -p "${VOLUME_PATH}"
fi

## Check if this is the Lowest create index
/giddyup leader check
if [ "$?" -ne "0" ]; then
    echo "The lowest numbered container handles volume operations... I'm not the lowest"
    sleep 5
    exit 0
fi

while [ "$(gluster pool list | grep Connected | wc -l)" -lt "${REPLICA_COUNT}" ]; do
    echo "Waiting for pool..."
    sleep 5
done

echo "Waiting for peerprobes and gluster daemons to come on line"
sleep 35

echo "Getting peer mount points..."
STATE_READY="true"
while true; do
    for container in $(/giddyup service containers -n); do
        IP=$(${IP_METHOD} ${container})

        if [ "$(gluster --remote-host=${IP} pool list | grep Connected | wc -l)" -ne "${REPLICA_COUNT}" ]; then
            echo "Peer mounts not ready...will retry"
            STATE_READY="false"
            continue
        fi
    done

    if [ "${STATE_READY}" = "true" ]; then
        break
    fi
    sleep 5
done
CONTAINER_MNTS=$(/giddyup ip stringify --delimiter " " --suffix ":${VOLUME_PATH}" ${STRINGIFY_OPTS})

if [ "$(gluster volume info ${VOLUME_NAME}|grep 'does\ not\ exist'|wc -l)" -ne "1" ]; then
    echo "Creating volume ${VOLUME_NAME}..."
    gluster volume create ${VOLUME_NAME} replica ${REPLICA_COUNT} transport tcp ${CONTAINER_MNTS}
    sleep 5
fi

if [ "$(gluster volume info ${VOLUME_NAME}| grep ^Status | tr -d '[[:space:]]' | cut -d':' -f2)" = "Created" ]; then
    echo "Starting volume ${VOLUME_NAME}..."
    gluster volume start ${VOLUME_NAME}
fi
