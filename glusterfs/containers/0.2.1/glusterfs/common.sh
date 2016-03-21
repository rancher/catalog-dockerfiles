#!/bin/bash

TCP_TIMEOUT=1
DAEMON_PORT=24007
META_URL="http://rancher-metadata/2015-07-25"

get_host_ip() {
    UUID=$(curl -s -H 'Accept: application/json' ${META_URL}/containers/${1}|jq -r '.host_uuid')
    IP=$(curl -s -H 'Accept: application/json' ${META_URL}/hosts |jq -r ".[] | select(.uuid==\"${UUID}\") | .agent_ip")
    echo ${IP}
}

get_host_name() {
    UUID=$(curl -s -H 'Accept: application/json' ${META_URL}/containers/${1}|jq -r '.host_uuid')
    IP=$(curl -s -H 'Accept: application/json' ${META_URL}/hosts |jq -r ".[] | select(.uuid==\"${UUID}\") | .name")
    echo ${IP}
}

get_container_primary_ip() {
    IP=$(curl -s -H 'Accept: application/json' ${META_URL}/containers/${1}|jq -r .primary_ip)
    echo ${IP}
}
