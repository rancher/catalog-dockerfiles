#!/bin/bash

# Let metadata come up
sleep 10
export META_URL="${1:-http://rancher-metadata/2015-07-25}"
export SCHEME="${SCHEME:=http}"

wait_for_all_service_containers()
{
    META_URL="${1:-http://rancher-metadata/2015-07-25}"
    SET_SCALE=$(curl -s -H 'Accept: application/json' ${META_URL}/self/service| jq -r .scale)
    while [ "$(curl -s -H 'Accept: application/json' ${META_URL}/self/service|jq '.containers |length')" -lt "${SET_SCALE}" ]; do
        sleep 1
    done
}

initial_cluster_string()
{
    local string=""
    for container in $(curl -s -H 'Accept: application/json' ${META_URL} | jq '.self.service.containers[]'); do
        create_index=$(curl -s -H 'Accept: application/json' ${META_URL} | jq -r ".containers[] | select(.name==${container}) | .create_index")
        container_ip=$(curl -s -H 'Accept: application/json' ${META_URL} | jq -r ".containers[] | select(.name==${container}) | .primary_ip")
        if [ "${string}" = "" ]; then
            string="etcd${create_index}=${SCHEME}://${container_ip}:2380"
            continue
        fi
        string="${string},etcd${create_index}=${SCHEME}://${container_ip}:2380"
    done
    echo $string
}

wait_for_all_service_containers

IP_ADDRESS=$(curl http://rancher-metadata/2015-07-25/self/container/primary_ip)
CREATE_INDEX=$(curl http://rancher-metadata/2015-07-25/self/container/create_index)
CLUSTER_NAME=$(curl http://rancher-metadata/2015-07-25/self/stack/name)


exec /etcd -name etcd${CREATE_INDEX} \
    -advertise-client-urls ${SCHEME}://${IP_ADDRESS}:2379,${SCHEME}://${IP_ADDRESS}:4001 \
    -listen-client-urls ${SCHEME}://0.0.0.0:2379,${SCHEME}://0.0.0.0:4001 \
    -initial-advertise-peer-urls ${SCHEME}://${IP_ADDRESS}:2380 \
    -listen-peer-urls ${SCHEME}://0.0.0.0:2380 \
    -initial-cluster-token ${CLUSTER_NAME} \
    -initial-cluster $(initial_cluster_string) \
    -initial-cluster-state new
