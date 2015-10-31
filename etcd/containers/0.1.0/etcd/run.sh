#!/bin/bash


set -x 

# Let metadata come up
sleep 10 

IP_ADDRESS=$(curl http://rancher-metadata/2015-07-25/self/container/primary_ip)
CREATE_INDEX=$(curl http://rancher-metadata/2015-07-25/self/container/create_index)
CLUSTER_NAME=$(curl http://rancher-metadata/2015-07-25/self/stack/name)

exec /etcd -name etcd${CREATE_INDEX} \
    -advertise-client-urls http://${IP_ADDRESS}:2379,http://${IP_ADDRESS}:4001 \
    -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
    -initial-advertise-peer-urls http://${IP_ADDRESS}:2380 \
    -listen-peer-urls http://0.0.0.0:2380 \
    -initial-cluster-token etcd-cluster-1 \
    -initial-cluster etcd${CREATE_INDEX}=http://${IP_ADDRESS}:2380 \
    -initial-cluster-state new
