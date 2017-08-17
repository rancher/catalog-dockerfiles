#!/bin/bash
if [ "$RANCHER_DEBUG" == "true" ]; then set -x; fi

META_URL="http://169.254.169.250/2015-12-19"

# loop until metadata wakes up...
STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
while [ "$STACK_NAME" == "" ]; do
  sleep 1
  STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
done

SCALE=$(giddyup service scale etcd)

while [ ! "$(echo $IP | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')" ]; do
    sleep 1
    IP=$(wget -q -O - ${META_URL}/self/container/primary_ip)
done

while [ ! "$(echo $SERVICE_INDEX | grep -E '^[0-9]+$')" ]; do
    sleep 1
    SERVICE_INDEX=$(wget -q -O - ${META_URL}/self/container/service_index)
done

CREATE_INDEX=$(wget -q -O - ${META_URL}/self/container/create_index)
HOST_UUID=$(wget -q -O - ${META_URL}/self/host/uuid)

# be very careful that all state goes into the data container
DATA_DIR=/data
DR_FLAG=$DATA_DIR/disaster
export ETCD_DATA_DIR=$DATA_DIR/etcd
export ETCDCTL_ENDPOINT=http://etcd.${STACK_NAME}:2379
export ETCDCTL_API=2

# member name should be dashed-IP (piggyback off of retain_ip functionality)
NAME="etcd-$SERVICE_INDEX"

etcdctl_quorum() {
    target_ip=0
    for container in $(giddyup service containers); do
        primary_ip=$(wget -q -O - ${META_URL}/self/service/containers/${container}/primary_ip)

        giddyup probe http://${primary_ip}:2379/health &> /dev/null
        if [ "$?" == "0" ]; then
            target_ip=$primary_ip
            break
        fi
    done
    if [ "$target_ip" == "0" ]; then
        echo No etcd nodes available
    else
        etcdctl --endpoints http://${primary_ip}:2379 $@
    fi
}

# may only be used for quorum=false reads
etcdctl_one() {
    target_ip=0
    for container in $(giddyup service containers); do
        primary_ip=$(wget -q -O - ${META_URL}/self/service/containers/${container}/primary_ip)

        giddyup probe tcp://${primary_ip}:2379 &> /dev/null
        if [ "$?" == "0" ]; then
            target_ip=$primary_ip
            break
        fi
    done
    if [ "$target_ip" == "0" ]; then
        echo No etcd nodes available
    else
        etcdctl --endpoints http://${primary_ip}:2379 $@
    fi
}

healthcheck_proxy() {
    WAIT=${1:-60s}
    etcdwrapper healthcheck-proxy --port=:2378 --wait=$WAIT --debug=false
}

cleanup() {
    exitcode=$1
    timestamp=$(date -R)
    echo "Exited ($exitcode)"

    if [ "$exitcode" == "0" ]; then
        rm -rf $ETCD_DATA_DIR
        echo "$timestamp -> Exit (0), member removed. Deleted data" >> $DATA_DIR/events

    elif [ "$exitcode" == "2" ]; then
        rm -rf $ETCD_DATA_DIR
        echo "$timestamp -> Exit (2), log corrupted, truncated, lost. Deleted data" >> $DATA_DIR/events

    elif [ "$exitcode" == "143" ]; then
        echo "$timestamp -> Exit (143), likely received SIGTERM. No action taken" >> $DATA_DIR/events

    else
        echo "$timestamp -> Exit ($exitcode), unknown. No action taken" >> $DATA_DIR/events
    fi

    # It's important that we return the exit code of etcd, otherwise scheduler might not delete/recreate
    # failed containers, leading to stale create_index which messes up `giddyup leader check`
    exit $exitcode
}

standalone_node() {
    # write IP to data directory for reference
    echo $IP > $ETCD_DATA_DIR/ip

    healthcheck_proxy 0s &
    etcd $@ \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster ${NAME}=http://${IP}:2380 \
        --initial-cluster-state new
    cleanup $?
}

restart_node() {
    healthcheck_proxy &
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster-state existing
    cleanup $?
}

# Scale Up
runtime_node() {
    rm -rf $ETCD_DATA_DIR/*
    timestamp=$(date -R)
    echo "$timestamp -> Scaling up. Deleted stale data" >> $DATA_DIR/events

    # Get leader create_index
    # Wait for nodes with smaller service index to become healthy
    for container in $(giddyup service containers --exclude-self); do
        echo Waiting for lower index nodes to all be active
        ctx_index=$(wget -q -O - ${META_URL}/self/service/containers/${container}/create_index)
        primary_ip=$(wget -q -O - ${META_URL}/self/service/containers/${container}/primary_ip)
        if [ "${ctx_index}" -lt "${CREATE_INDEX}" ]; then
            giddyup probe http://${primary_ip}:2379/health --loop --min 1s --max 15s --backoff 1.2
        fi
    done

    # We can almost use giddyup here, need service index templating {{service_index}}
    # giddyup ip stringify --prefix etcd{{service_index}}=http:// --suffix :2380
    # etcd1=http://10.42.175.109:2380,etcd2=http://10.42.58.73:2380,etcd3=http://10.42.96.222:2380
    for container in $(giddyup service containers); do
        ctx_index=$(wget -q -O - ${META_URL}/self/service/containers/${container}/create_index)

        # simulate step-scale policy by ignoring create_indeces greater than our own
        if [ "${ctx_index}" -gt "${CREATE_INDEX}" ]; then
            continue
        fi

        cip=$(wget -q -O - ${META_URL}/self/service/containers/${container}/primary_ip)
        cname="etcd-$(wget -q -O - ${META_URL}/self/service/containers/${container}/service_index)"
        if [ "$cluster" != "" ]; then
            cluster=${cluster},
        fi
        cluster=${cluster}${cname}=http://${cip}:2380
    done

    etcdctl_quorum member add $NAME http://${IP}:2380

    # write container IP to data directory for reference
    echo $IP > $ETCD_DATA_DIR/ip

    healthcheck_proxy &
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster-state existing \
        --initial-cluster $cluster
    cleanup $?
}

# recoverable failure scenario
recover_node() {
    rm -rf $ETCD_DATA_DIR/*
    timestamp=$(date -R)
    echo "$timestamp -> Recovering. Deleted stale data" >> $DATA_DIR/events

    # figure out which node we are replacing
    oldnode=$(etcdctl_quorum member list | grep "$NAME" | tr ':' '\n' | head -1 | sed 's/\[unstarted\]//')

    # remove the old node
    etcdctl_quorum member remove $oldnode

    # create cluster parameter based on etcd state (can't use rancher metadata)
    while read -r member; do
        name=$(echo $member | tr ' ' '\n' | grep name | tr '=' '\n' | tail -1)
        peer_url=$(echo $member | tr ' ' '\n' | grep peerURLs | tr '=' '\n' | tail -1)
        if [ "$cluster" != "" ]; then
            cluster=${cluster},
        fi
        cluster=${cluster}${name}=${peer_url}
    done <<< "$(etcdctl_quorum member list | grep -v unstarted)"
    cluster=${cluster},${NAME}=http://${IP}:2380

    etcdctl_quorum member add $NAME http://${IP}:2380

    # write container IP to data directory for reference
    echo $IP > $ETCD_DATA_DIR/ip

    healthcheck_proxy &
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster-state existing \
        --initial-cluster $cluster
    cleanup $?
}

disaster_node() {
    local skip_hash_check
    skip_hash_check="${1:-false}"

    rm -rf $ETCD_DATA_DIR
    ETCDCTL_API=3 etcdctl snapshot restore $DATA_DIR/snapshot \
        --name=${NAME} \
        --data-dir=$ETCD_DATA_DIR \
        --initial-advertise-peer-urls=http://${IP}:2380 \
        --initial-cluster="$NAME=http://${IP}:2380" \
        --skip-hash-check="$skip_hash_check"

    if [ $? -ne 0 ]; then
        echo Error restoring snapshot! Aborting.
        exit 1
    fi

    rm -rf $DR_FLAG
    standalone_node --force-new-cluster
}

node() {
    mkdir -p $ETCD_DATA_DIR

    # if the DR flag is set, enter disaster recovery
    if [ -f "$DR_FLAG" ]; then
        echo Disaster Recovery
        disaster_node

    # if we have a data volume and it was served by a container with same IP
    elif [ -d "$ETCD_DATA_DIR/member" ] && [ "$(cat $ETCD_DATA_DIR/ip)" == "$IP" ]; then

        # if the migration flag is set, upgrade to v3
        if [ "$ETCD_MIGRATE" == "v3" ]; then
            ETCDCTL_API=3 etcdctl migrate --data-dir=$ETCD_DATA_DIR
        fi

        echo Restarting Existing Node
        restart_node

    # if this member is already registered to the cluster but no data volume, we are recovering
    elif [ "$(etcdctl_one member list | grep $NAME)" ]; then
        echo Recovering existing node data directory
        recover_node

    # if we are the first etcd to start
    elif giddyup leader check; then

        # if we have a backup dir with at one or more snapshots, trigger an autormatic disaster recovery
        if [ -d "/backup" ] && [ "$(ls /backup | wc -l)" != "0" ]; then
            echo Found a backup. Attempting Disaster Recovery
            cp "/backup/$(ls /backup | tail -1)" $DATA_DIR/snapshot
            touch $DR_FLAG
            disaster_node true

        # if we have an old data dir, trigger an automatic disaster recovery
        elif [ -f "$ETCD_DATA_DIR/member/snap/db" ]; then
            echo Found old cluster data. Attempting Disaster Recovery
            cp $ETCD_DATA_DIR/member/snap/db $DATA_DIR/snapshot
            touch $DR_FLAG
            disaster_node true

        # otherwise, start a new cluster
        else
            echo Bootstrapping Cluster
            standalone_node
        fi

    # we are scaling up
    else
        echo Adding Node
        runtime_node
    fi
}

if [ $# -eq 0 ]; then
    echo No command specified, running in standalone mode.
    standalone_node
else
    eval $1
fi
