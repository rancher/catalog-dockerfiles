#!/bin/bash

. /opt/rancher/common.sh

echo "Waiting for all containers to come up..."
wait_for_all_service_containers
echo "Containers are coming up..."

META_URL="http://rancher-metadata/2015-07-25"

ALLMETA=$(curl -s -H 'Accept: application/json' ${META_URL})
VOLUME_NAME=$(echo ${ALLMETA} | jq -r '.self.service.metadata.volume_name')
BRICK_PATH="/data/glusterfs/brick1"
VOLUME_PATH="${BRICK_PATH}/${VOLUME_NAME}"
REPLICA_COUNT=$(echo ${ALLMETA} | jq -r '.self.service.scale')

if [ ! -f ${VOLUME_PATH} ]; then
    mkdir -p "${VOLUME_PATH}"
fi

## Check if this is the Lowest create index
/opt/rancher/lowest_idx.sh
if [ "$?" -ne "0" ]; then
    echo "The lowest numbered container handles volume operations... I'm not the lowest"
    exit 0
fi

while [ "$(gluster pool list | grep Connected | wc -l)" -lt "${REPLICA_COUNT}" ]; do
    echo "Waiting for pool..."
    sleep 5
done

echo "Getting peer mount points..."
STATE_READY="true"
while true; do
    CONTAINER_MNTS=""

    for container in $(curl -s -H 'Accept: application/json' ${META_URL} | jq '.self.service.containers[]'); do
        IP=$(curl -s -H 'Accept: application/json' ${META_URL} | jq -r ".containers[] | select(.name==${container}) | .primary_ip")

        if [ "$(gluster --remote-host=${IP} pool list | grep Connected | wc -l)" -ne "${REPLICA_COUNT}" ]; then
            echo "Peer mounts not ready...will retry"
            STATE_READY="false"
            continue
        fi

        CONTAINER_MNTS="$CONTAINER_MNTS ${IP}:${VOLUME_PATH}"
    done

    if [ "${STATE_READY}" = "true" ]; then
        break
    fi
    sleep 5
done

if [ "$(gluster volume info ${VOLUME_NAME}|grep 'does\ not\ exist'|wc -l)" -ne "1" ]; then
    echo "Creating volume ${VOLUME_NAME}..."
    gluster volume create ${VOLUME_NAME} replica ${REPLICA_COUNT} transport tcp ${CONTAINER_MNTS}
    sleep 5
fi

if [ "$(gluster volume info ${VOLUME_NAME}| grep ^Status | tr -d '[[:space:]]' | cut -d':' -f2)" = "Created" ]; then
    echo "Starting volume ${VOLUME_NAME}..."
    gluster volume start ${VOLUME_NAME}
fi
