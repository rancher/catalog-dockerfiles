#!/bin/bash
if [ "$RANCHER_DEBUG" == "true" ]; then set -x; fi

SCALE=$(giddyup service scale etcd)
IP=$(giddyup ip myip)
META_URL="http://rancher-metadata.rancher.internal/2015-12-19"
STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
CREATE_INDEX=$(wget -q -O - ${META_URL}/self/container/create_index)
NAME=$(wget -q -O - ${META_URL}/self/container/name)

# be very careful that all state goes into the data container
DATA_DIR=/data
DR_FLAG=$DATA_DIR/DR
export ETCD_DATA_DIR=$DATA_DIR/data.current
export ETCDCTL_ENDPOINT=http://etcd.${STACK_NAME}:2379

etcdctln() {
    target=0
    for j in $(seq 1 5); do
        for i in $(seq 1 $SCALE); do
            giddyup probe http://${STACK_NAME}_etcd_${i}:2379/health &> /dev/null
            if [ "$?" == "0" ]; then
                target=$i
                break
            fi
        done
        if [ "$target" != "0" ]; then
            break
        fi
        sleep 1
    done
    if [ "$target" == "0" ]; then
        echo No etcd nodes available
    else
        etcdctl --endpoints http://${STACK_NAME}_etcd_$target:2379 $@
    fi
}

standalone_node() {
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster ${NAME}=http://${IP}:2380 \
        --initial-cluster-state new
}

restart_node() {
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster-state existing
}

# Scale Up
runtime_node() {

    # Get leader create_index
    # Wait for nodes with smaller service index to become healthy
    for container in $(giddyup service containers --exclude-self); do
        echo Waiting for lower index nodes to all be active
        ctx_index=$(wget -q -O - ${META_URL}/self/service/containers/${container}/create_index)
        if [ "${ctx_index}" -lt "${CREATE_INDEX}" ]; then
            giddyup probe http://${container}:2379/health --loop --min 1s --max 15s --backoff 1.2
        fi
    done

    # We can almost use giddyup here, need service index templating {{service_index}}
    # giddyup ip stringify --prefix etcd{{service_index}}=http:// --suffix :2380
    # etcd1=http://10.42.175.109:2380,etcd2=http://10.42.58.73:2380,etcd3=http://10.42.96.222:2380
    for container in $(wget -q -O - ${META_URL}/self/service/containers); do
        meta_index=$(echo $container | tr '=' '\n' | head -n1)
        ctx_index=$(wget -q -O - ${META_URL}/self/service/containers/${meta_index}/create_index)
        container_name=$(wget -q -O - ${META_URL}/self/service/containers/${meta_index}/name)

        # simulate step-scale policy by ignoring create_indeces greater than our own
        if [ "${ctx_index}" -gt "${CREATE_INDEX}" ]; then
            continue
        fi

        cip=$(wget -q -O - ${META_URL}/self/service/containers/${meta_index}/primary_ip)
        if [ "$cluster" != "" ]; then
            cluster=${cluster},
        fi
        cluster=${cluster}${container_name}=http://${cip}:2380
    done

    etcdctln member add $NAME http://${IP}:2380

    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster-state existing \
        --initial-cluster $cluster
}

# recoverable failure scenario
recover_node() {
    # figure out which node we are replacing
    oldnode=$(etcdctln member list | grep "$NAME" | tr ':' '\n' | head -1)

    # remove the old node
    etcdctln member remove $oldnode

    # create cluster parameter based on etcd state (can't use rancher metadata)
    while read -r member; do
        name=$(echo $member | tr ' ' '\n' | grep name | tr '=' '\n' | tail -1)
        peer_url=$(echo $member | tr ' ' '\n' | grep peerURLs | tr '=' '\n' | tail -1)
        if [ "$cluster" != "" ]; then
            cluster=${cluster},
        fi
        cluster=${cluster}${name}=${peer_url}
    done <<< "$(etcdctl member list | grep -v unstarted)"
    cluster=${cluster},${NAME}=http://${IP}:2380

    etcdctln member add $NAME http://${IP}:2380

    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster-state existing \
        --initial-cluster $cluster
}

disaster_node() {
    BACKUP_DIR=${DATA_DIR}/data.$(date +"%Y%m%d.%H%M%S").DR

    echo "Creating a DR backup..."
    etcdctl backup \
        --data-dir $ETCD_DATA_DIR \
        --backup-dir $BACKUP_DIR
    
    echo "Sanitizing DR backup..."
    etcd \
        --name ${NAME} \
        --data-dir $BACKUP_DIR \
        --force-new-cluster &
    PID=$!

    # wait until etcd reports healthy
    giddyup probe http://127.0.0.1:2379/health --loop --min 1s --max 15s --backoff 1.2

    # Disaster recovery ignores peer-urls flag, so we update it

    # query etcd for its old member ID
    while [ "$oldnode" == "" ]; do
        oldnode=$(etcdctl member list | grep "$NAME" | tr ':' '\n' | head -1)
        sleep 1
    done
    
    # etcd says it is healthy, but writes fail for a while...so keep trying until it works
    etcdctl member update $oldnode http://${IP}:2380
    while [ "$?" != "0" ]; do
        sleep 1
        etcdctl member update $oldnode http://${IP}:2380
    done

    # shutdown the disaster node cleanly
    kill $PID
    while kill -0 $PID &> /dev/null; do
        sleep 1
    done

    echo "Copying sanitized DR backup to data directory..."
    rm -rf $ETCD_DATA_DIR/*
    cp -rf $BACKUP_DIR/* $ETCD_DATA_DIR/

    # remove the DR flag
    rmdir $DR_FLAG

    # become a new standalone node
    standalone_node
}

node() {
    # if the DR flag is set, enter disaster recovery
    if [ -d "$DR_FLAG" ]; then
        disaster_node

    # if we have a data volume, we are upgrading/restarting
    elif [ -d "$ETCD_DATA_DIR/member" ]; then
        restart_node

    elif giddyup leader check; then
        standalone_node

    # if this member is already registered to the cluster but no data volume, we are recovering
    elif [ "$(etcdctln member list | grep $NAME)" != "" ]; then
        recover_node

    # we are scaling up
    else
        runtime_node
    fi
}

if [ $# -eq 0 ]; then
    echo No command specified, running in standalone mode.
    standalone_node
else
    eval $1
fi
