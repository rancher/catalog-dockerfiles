#!/bin/bash

export MASTERS=
export ZK=

get_container_ip()
{
    local container=${1}
    echo $(curl -s -H 'Accept: application/json' "${METADATA_URL}" | jq -r ".containers[] | select(.name==${container}) | .primary_ip")
}

get_master_string()
{
    for container in $(curl -s -H 'Accept: application/json' "${METADATA_URL}"|jq '.services[] | select(.name=="spark-master") | .containers[]'); do
        if [ -z "$MASTERS" ]; then
            MASTERS="spark://$(get_container_ip ${container}):7077"
        else
            MASTERS="${MASTERS},$(get_container_ip ${container}):7077"
        fi
    done
    echo "${MASTERS}"
}

get_zookeeper_string()
{
    for container in $(curl -s -H 'Accept: application/json' "${METADATA_URL}"|jq -r '.services[] | select(.name=="zookeeper") | .containers[]'); do
        if [ -z "$ZK" ]; then
            ZK="${container}:2181"
        else
            ZK="${ZK},${container}:2181"
        fi
    done

    echo "${ZK}"
}
