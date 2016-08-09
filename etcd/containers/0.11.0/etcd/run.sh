#!/bin/bash
if [ "$RANCHER_DEBUG" == "true" ]; then set -x; fi

SCALE=$(giddyup service scale etcd)
IP=$(giddyup ip myip)
META_URL="http://rancher-metadata.rancher.internal/2015-12-19"
STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
CREATE_INDEX=$(wget -q -O - ${META_URL}/self/container/create_index)
HOST_UUID=$(wget -q -O - ${META_URL}/self/host/uuid)

# be very careful that all state goes into the data container
LEGACY_DATA_DIR=/data
DATA_DIR=/pdata
DR_FLAG=$DATA_DIR/DR
export ETCD_DATA_DIR=$DATA_DIR/data.current
export ETCDCTL_ENDPOINT=http://etcd.${STACK_NAME}:2379

# member name should be dashed-IP (piggyback off of retain_ip functionality)
NAME=$(echo $IP | tr '.' '-')

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
    etcdwrapper healthcheck-proxy --port=:2378 --wait=60s --debug=false
}

create_backup() {
    backup_type=$1
    target_dir=$2

    backup_dir=${DATA_DIR}/data.$(date +"%Y%m%d.%H%M%S").${backup_type}

    etcdctl backup \
        --data-dir $target_dir \
        --backup-dir $backup_dir

    echo $backup_dir
}

rolling_backup() {
    BACKUP_PERIOD=${BACKUP_PERIOD:-5m}
    BACKUP_RETENTION=${BACKUP_RETENTION:-24h}

    giddyup leader elect --proxy-tcp-port=2160 \
        etcdwrapper rolling-backup \
            --period=$BACKUP_PERIOD \
            --retention=$BACKUP_RETENTION
}

cleanup() {
    exitcode=$1
    timestamp=$(date --rfc-3339=seconds)
    echo "Exited ($exitcode)"

    if [ "$exitcode" == "0" ]; then
        rm -rf $ETCD_DATA_DIR
        echo "$timestamp -> Exit (0), member removed. Deleted data" >> $DATA_DIR/events

    elif [ "$exitcode" == "2" ]; then
        rm -rf $ETCD_DATA_DIR
        echo "$timestamp -> Exit (2), log corrupted, truncated, lost. Deleted data" >> $DATA_DIR/events

    else
        echo "$timestamp -> Exit ($exitcode), unknown. No action taken" >> $DATA_DIR/events
    fi
}

standalone_node() {
    # write IP to data directory for reference
    echo $IP > $ETCD_DATA_DIR/ip

    healthcheck_proxy &
    etcd \
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
    # explicitly backup and wipe any old data dir
    if [ -d "$ETCD_DATA_DIR/member" ]; then
        rm -rf $ETCD_DATA_DIR/*
        timestamp=$(date --rfc-3339=seconds)
        echo "$timestamp -> Scaling up. Deleted stale data" >> $DATA_DIR/events
    fi

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
        cname=$(echo $cip | tr '.' '-')
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
    # figure out which node we are replacing
    oldnode=$(etcdctl_quorum member list | grep "$NAME" | tr ':' '\n' | head -1)

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
    RECOVERY_DIR=${DATA_DIR}/$(cat $DR_FLAG)

    # always backup the current dir
    if [ "$RECOVERY_DIR" == "${DATA_DIR}/data.current" ]; then
        RECOVERY_DIR=$(create_backup DR $RECOVERY_DIR)
    fi
    
    echo "Sanitizing backup..."
    etcd \
        --name ${NAME} \
        --data-dir $RECOVERY_DIR \
        --force-new-cluster &
    PID=$!

    # wait until etcd reports healthy
    giddyup probe http://127.0.0.1:2379/health --loop --min 1s --max 15s --backoff 1.2

    # Disaster recovery ignores peer-urls flag, so we update it

    # query etcd for its old member ID
    while [ "$oldnode" == "" ]; do
        oldnode=$(etcdctl --endpoints=http://127.0.0.1:2379 member list | grep "$NAME" | tr ':' '\n' | head -1)
        sleep 1
    done
    
    # etcd says it is healthy, but writes fail for a while...so keep trying until it works
    etcdctl --endpoints=http://127.0.0.1:2379 member update $oldnode http://${IP}:2380
    while [ "$?" != "0" ]; do
        sleep 1
        etcdctl --endpoints=http://127.0.0.1:2379 member update $oldnode http://${IP}:2380
    done

    # shutdown the node cleanly
    while kill -0 $PID &> /dev/null; do
        kill $PID
        sleep 1
    done

    echo "Copying sanitized backup to data directory..."
    mkdir -p ${ETCD_DATA_DIR}
    rm -rf ${ETCD_DATA_DIR}/*
    cp -rf $RECOVERY_DIR/* ${ETCD_DATA_DIR}/

    # remove the DR flag
    rm -rf $DR_FLAG

    # TODO (llparse) kill all other etcd nodes

    # become a new standalone node
    standalone_node
}

node() {

    if [ -d "$LEGACY_DATA_DIR/member" ]; then
        echo "Upgrading FS structure from version <= etcd:v2.3.6-4 to etcd:v2.3.7-6"
        mkdir -p $LEGACY_DATA_DIR/data.current
        mv $LEGACY_DATA_DIR/member $LEGACY_DATA_DIR/data.current/
        node

    elif [ -d "$LEGACY_DATA_DIR/data.current" ]; then
        echo "Upgrading FS structure from version = rancher/etcd:v2.3.7-6 to current"
        mkdir -p $ETCD_DATA_DIR
        mv $LEGACY_DATA_DIR/data.current/member $ETCD_DATA_DIR/
        rm -rf $LEGACY_DATA_DIR/data.current
        echo $IP > $ETCD_DATA_DIR/ip
        node

    # if the DR flag is set, enter disaster recovery
    elif [ -f "$DR_FLAG" ]; then
        disaster_node

    # if we have a data volume and it was served by a container with same IP
    elif [ -d "$ETCD_DATA_DIR/member" ] && [ "$(cat $ETCD_DATA_DIR/ip)" == "$IP" ]; then
        restart_node

    # if we are the first etcd to start
    elif giddyup leader check; then

        # if we have an old data dir, trigger an automatic disaster recovery (tee-hee)
        if [ -d "$ETCD_DATA_DIR/member" ]; then
            echo data.current > $DR_FLAG
            disaster_node

        # otherwise, start a new cluster
        else
            standalone_node
        fi

    # if this member is already registered to the cluster but no data volume, we are recovering
    elif [ "$(etcdctl_one member list | grep $NAME)" ]; then
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
