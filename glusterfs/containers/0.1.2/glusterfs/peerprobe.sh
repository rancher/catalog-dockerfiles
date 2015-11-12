#!/bin/bash
set -e

. /opt/rancher/common.sh

META_URL="http://rancher-metadata/2015-07-25"
SELF_NAME=$(curl -s -H 'Accept: application/json' ${META_URL}/self/container| jq -r .name)

echo "Waiting for all service containers to start..."
wait_for_all_service_containers
echo "Containers are starting..."

# let the services come up
echo "Waiting for Gluster Daemons to come up"
sleep 30

peer_probe_hosts()
{    
    for peer in $(curl -s -H 'Accept: application/json' ${META_URL}/self/service| jq -r .containers[]); do
        if [ "${peer}" != "${SELF_NAME}" ]; then
            IP=$(curl -s -H 'Accept: application/json' ${META_URL}/containers/${peer}|jq -r .primary_ip)
            echo gluster peer probe ${IP}
            gluster peer probe ${IP}
            sleep .5
        fi
    done
}


while true; do
    PEER_COUNT=$(gluster pool list|grep -v UUID|wc -l)
    if [ "$(curl -s -H 'Accept: application/json' ${META_URL}/self/service| jq -r .scale)" -ne "${PEER_COUNT}" ]; then
        peer_probe_hosts
    fi
    sleep 15
done
