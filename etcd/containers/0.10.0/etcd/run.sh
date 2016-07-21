#!/bin/bash
if [ "$RANCHER_DEBUG" == "true" ]; then set -x; fi

BACKUP_DIR=${BACKUP_DIR:-/data.backup}
SCALE=$(giddyup service scale etcd)

IP=$(giddyup ip myip)
META_URL="http://rancher-metadata.rancher.internal/2015-12-19"
STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
CREATE_INDEX=$(wget -q -O - ${META_URL}/self/container/create_index)
NAME=$(wget -q -O - ${META_URL}/self/container/name)
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

discovery_node() {
    etcd \
        -name discovery \
        -advertise-client-urls http://${IP}:6666 \
        -listen-client-urls http://0.0.0.0:6666
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
            giddyup probe http://${container}:2379/health --loop --min 1s --max 60s --backoff 1.1
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

# failure scenario
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
    echo "Archiving data directory..."
    # archive data directory before doing anything
    cp -rf $ETCD_DATA_DIR ${ETCD_DATA_DIR}.old

    echo "Creating a backup..."
    etcdctl backup --data-dir $ETCD_DATA_DIR --backup-dir $BACKUP_DIR
    
    echo "Sanitizing backup..."
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster ${NAME}=http://${IP}:2380 \
        --data-dir ${BACKUP_DIR} \
        --force-new-cluster &
    PID=$!

    # wait until the backup dir has been sanitized
    giddyup probe http://127.0.0.1:2379/health --loop --min 1s --max 60s --backoff 1.1

    # for some reason, disaster recovery ignores peer-urls flag so we update it
    oldnode=$(etcdctln member list | grep "$NAME" | tr ':' '\n' | head -1)
    etcdctl member update $oldnode http://${IP}:2380

    # kill the disaster node
    while kill -0 $PID &> /dev/null; do
        kill $PID
        sleep 1
    done

    # copy the sanitized backup to the data directory
    echo "Copying sanitized backup to data directory..."
    cp -rf $BACKUP_DIR/* $ETCD_DATA_DIR/

    # delete the backup so we don't re-enter disaster recovery
    echo "Deleting backup..."
    rm -rf $BACKUP_DIR

    # become a new standalone node
    standalone_node
}

node() {
    # if we have a backup volume, we are recovering from a disaster
    if [ -d "$BACKUP_DIR" ]; then
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
