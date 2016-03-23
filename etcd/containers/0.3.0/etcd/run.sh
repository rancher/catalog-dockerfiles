#!/bin/bash

if [ $# -eq 0 ]; then
    echo Specify a command
    exit 1
fi
command=$1

SIZE=1
if [ $# -gt 1 ]; then
    SIZE=$2
fi

# parameterize in templates?
UUID=6c007a14875d53d9bf0ef5a6fc0257c817f0fb84
DATA_DIR=/data

META_URL="http://rancher-metadata/2015-12-19"
# only http scheme is supported
SCHEME=http
#CLUSTER_NAME=$(curl ${META_URL}/self/stack/name)

# Using hostname for advertising would be better, but etcd resolves it to the docker IP
while true; do
    IP_ADDRESS=$(curl -s ${META_URL}/self/container/primary_ip)
    if [ "$IP_ADDRESS" != "" ] && [ "$IP_ADDRESS" != "Not found" ]; then
        break
    fi
    sleep 1
done

bootstrap()
{
    echo Waiting for discovery node to become ready
    while true; do
        >/dev/tcp/etcd-discovery/6666
        if [ "$?" -eq "0" ]; then
            break
        fi
        sleep 1
    done

    echo Telling discovery node about new cluster $UUID of size $SIZE
    if [ "$(curl -s -X PUT http://etcd-discovery:6666/v2/keys/discovery/$UUID/_config/size -d value=$SIZE | jq -r .node.value)" != "$SIZE" ]; then
        echo ERROR: Could not set cluster size
        exit 1
    fi
    sleep 1

    echo Waiting for cluster members to register
    size=0
    remaining=$SIZE
    until [ "$size" == "$SIZE" ]; do
        size=$(curl -s http://etcd-discovery:6666/v2/keys/discovery/$UUID | jq '.node.nodes | length')
        if [ "$(($SIZE - $size))" != "$remaining" ]; then
            remaining=$(($SIZE - $size))
            echo "found $size peer(s), waiting for $remaining more"
        fi
        sleep 1
    done

    echo Checking if cluster members know about eachother
    size=0
    until [ "$size" == "$SIZE" ]; do
        size=$(curl -m 3 -s etcd:2379/v2/members | jq '.members | length')
        echo "random member sees cluster size=$size"
        sleep 1
    done

    echo Setting cluster state to RUNNING
    if [ "$(curl -s -X PUT http://etcd:2379/v2/keys/_state -d value="RUNNING" | jq -r .node.value)" != "RUNNING" ]; then
        echo ERROR: Could not set cluster state
        exit 1
    fi

    echo Shutting down discovery node
    ID=$(curl -s -X GET http://etcd-discovery:6666/v2/members | jq -r .members[0].id)
    curl -s -X DELETE http://etcd-discovery:6666/v2/members/$ID

    echo Successfully bootstrapped cluster $UUID
    sleep 1
}

discovery_node()
{
    echo Discovery started

    etcd -name etcd-discovery \
        -advertise-client-urls ${SCHEME}://${IP_ADDRESS}:6666 \
        -listen-client-urls ${SCHEME}://0.0.0.0:6666 &> /dev/null

    # deleting the last member in a 1-node etcd cluster causes 
    # panic: runtime error: index out of range
    # so we will exit quietly to suppress service/stack degradation
    exit 0
}

# initial deployment
run_initial_node()
{
    # wait until registration key exists
    while [ "$(curl -s etcd-discovery:6666/v2/keys/discovery/$UUID | jq -r .action)" != "get" ]; do
        echo Registration key not yet created
        sleep 1
    done

    etcd --name ${NAME} \
        --data-dir ${DATA_DIR} \
        --listen-client-urls ${SCHEME}://0.0.0.0:2379 \
        --advertise-client-urls ${SCHEME}://${IP_ADDRESS}:2379 \
        --listen-peer-urls ${SCHEME}://0.0.0.0:2380 \
        --initial-advertise-peer-urls ${SCHEME}://${IP_ADDRESS}:2380 \
        --initial-cluster-state new \
        --discovery http://etcd-discovery:6666/v2/keys/discovery/$UUID
}

# restarts and upgrades
run_restart_node()
{
    etcd --name ${NAME} \
        --data-dir ${DATA_DIR} \
        --listen-client-urls ${SCHEME}://0.0.0.0:2379 \
        --advertise-client-urls ${SCHEME}://${IP_ADDRESS}:2379 \
        --listen-peer-urls ${SCHEME}://0.0.0.0:2380 \
        --initial-advertise-peer-urls ${SCHEME}://${IP_ADDRESS}:2380 \
        --initial-cluster-state existing
}

# scale up
run_active_node()
{
    for container in $(curl -s ${META_URL}/services/etcd/containers); do
        meta_index=$(echo $container | tr '=' '\n' | head -n1)
        service_index=$(curl -s ${META_URL}/services/etcd/containers/${meta_index}/service_index)
        ip=$(curl -s ${META_URL}/services/etcd/containers/${meta_index}/primary_ip)
        if [ "$cluster" != "" ]; then
            cluster=${cluster},
        fi
        cluster=${cluster}etcd${service_index}=${SCHEME}://${ip}:2380
    done

    curl -s ${SCHEME}://etcd:2379/v2/members -XPOST \
        -H "Content-Type: application/json" \
        -d "{\"peerURLs\":[\"http://${IP_ADDRESS}:2380\"]}"

    etcd --name ${NAME} \
        --data-dir ${DATA_DIR} \
        --listen-client-urls ${SCHEME}://0.0.0.0:2379 \
        --advertise-client-urls ${SCHEME}://${IP_ADDRESS}:2379 \
        --listen-peer-urls ${SCHEME}://0.0.0.0:2380 \
        --initial-advertise-peer-urls ${SCHEME}://${IP_ADDRESS}:2380 \
        --initial-cluster-state existing \
        --initial-cluster $cluster
}

node()
{
    SERVICE_INDEX=$(curl -s ${META_URL}/self/container/service_index)
    NAME=etcd${SERVICE_INDEX}

    state=initial
    # if this member is already registered to the cluster, we are upgrading/restarting
    if [ "$(curl -m 3 -s http://etcd:2379/v2/members | jq -r ".members[] | select(.name == \"$NAME\") | .name")" == "$NAME" ]; then
        state=restart
    # if the cluster is already running, we are scaling up
    elif [ "$(curl -m 3 -s http://etcd:2379/v2/keys/_state | jq -r .node.value)" == "RUNNING" ]; then
    # etcdctl sometimes hangs indefinitely despite 5s max time default setting, so we use curl
    #if [ "$(/etcdctl --endpoints http://etcd:2379 get _state)" == "RUNNING" ]; then
        state=active
    fi
    eval run_${state}_node
}

eval ${command}
