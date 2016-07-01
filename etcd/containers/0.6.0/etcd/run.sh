#!/bin/bash
if [ "$RANCHER_DEBUG" == "true" ]; then set -x; fi

DISCOVERY=http://discovery:6666
UUID=6c007a14875d53d9bf0ef5a6fc0257c817f0fb84

IP=$(giddyup ip myip)
SCALE=$(giddyup service scale etcd)

MIN_SCALE=$(wget -q -O - http://rancher-metadata/latest/self/service/metadata/scale_policy/min)
META_URL="http://rancher-metadata.rancher.internal/2015-12-19"
STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
SERVICE_INDEX=$(wget -q -O - ${META_URL}/self/container/service_index)
NAME=etcd${SERVICE_INDEX}
export ETCDCTL_ENDPOINT=http://etcd.${STACK_NAME}:2379

etcdctld() {
    etcdctl --no-sync --endpoints $DISCOVERY $@
}

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

get_state() {
    # giddyup probe loop runs forever so we must do single calls or we may block forever
    etcdctln get _state
#    state=NOKEY
#    for i in $(seq 1 5); do
#        giddyup probe http://etcd:2379/health &> /dev/null
#        if [ "$?" == "0" ]; then
#            state=$(etcdctl get _state)
#        fi
#        sleep 1
#    done
#    echo $state
}

set_state() {
    echo Setting cluster state to $1

    if [ "$(etcdctln set _state $1)" != "$1" ]; then
        echo ERROR: Could not set cluster state
        exit 1
    fi
}

bootstrap() {
    echo Waiting for discovery node to become ready
    giddyup probe $DISCOVERY/health --loop --min 1s --max 60s --backoff 1.1

    if [ "$(etcdctln get _state)" != "RUNNING" ]; then
        if [ "$SCALE" != "1" ]; then
            echo Telling discovery node about new cluster of size $SCALE
            if [ "$(etcdctld set discovery/$UUID/_config/size $SCALE)" != "$SCALE" ]; then
                echo ERROR: Could not set cluster size
                exit 1
            fi

            echo Waiting for cluster members to register
            size=0
            remaining=$SCALE
            until [ "$size" == "$SCALE" ]; do
                size=$(etcdctld ls discovery/$UUID | wc -l)
                if [ "$(($SCALE - $size))" != "$remaining" ]; then
                    remaining=$(($SCALE - $size))
                    echo "found $size peer(s), waiting for $remaining more"
                fi
                sleep 1
            done

            echo Checking if we see all cluster members
            size=0
            until [ "$size" == "$SCALE" ]; do
                size=$(etcdctl --no-sync --endpoints http://etcd:2379 member list | wc -l)
                echo "A member sees cluster size=$size"
                sleep 1
            done
        else
            echo Bootstrapping a 1-node etcd is a no-op, consider not running discovery service
        fi

        giddyup probe http://etcd:2379/health --loop --min 1s --max 60s --backoff 1.1
        set_state RUNNING
    else
        echo Cluster is already running
    fi

    echo Shutting down discovery node
    etcdctld member remove $(etcdctld member list | tr ':' '\n' | head -1)

    echo Successfully bootstrapped cluster
    sleep 1
}

discovery_node() {
    etcd \
        -name discovery \
        -advertise-client-urls http://${IP}:6666 \
        -listen-client-urls http://0.0.0.0:6666
}

bootstrap_node() {
    echo Waiting for discovery node to become healthy
    giddyup probe $DISCOVERY/health --loop --min 1s --max 60s --backoff 1.1

    echo Waiting for registration key to be created
    while true; do
        etcdctld ls discovery/$UUID
        if [ "$?" -eq "0" ]; then
            break
        fi
        sleep 1
    done

    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster-state new \
        --discovery $DISCOVERY/v2/keys/discovery/$UUID
}

standalone_node() {
    set_state RUNNING &
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster etcd1=http://${IP}:2380 \
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
    # Wait for nodes with smaller service index to become healthy
    if [ "$(($SERVICE_INDEX > 1))" == "1" ]; then
        echo Waiting for lower index nodes to all be active
        for i in $(seq 1 $(($SERVICE_INDEX - 1))); do
            giddyup probe http://${STACK_NAME}_etcd_${i}:2379/health --loop --min 1s --max 60s --backoff 1.1
        done
    fi

    # We can almost use giddyup here, need service index templating {{service_index}}
    # giddyup ip stringify --prefix etcd{{service_index}}=http:// --suffix :2380
    # etcd1=http://10.42.175.109:2380,etcd2=http://10.42.58.73:2380,etcd3=http://10.42.96.222:2380
    for container in $(wget -q -O - ${META_URL}/self/service/containers); do
        meta_index=$(echo $container | tr '=' '\n' | head -n1)
        service_index=$(wget -q -O - ${META_URL}/self/service/containers/${meta_index}/service_index)

        # simulate step-scale policy by ignoring service_indeces greater than our own (except during recovery)
        if [ "$(($service_index > $SERVICE_INDEX))" == "1" ]; then
            continue
        fi

        cip=$(wget -q -O - ${META_URL}/self/service/containers/${meta_index}/primary_ip)
        if [ "$cluster" != "" ]; then
            cluster=${cluster},
        fi
        cluster=${cluster}etcd${service_index}=http://${cip}:2380
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
    oldnode=$(etcdctln member list | grep $NAME | tr ':' '\n' | head -1)

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

node() {
    if [ "$SCALE" == "1" ]; then
        standalone_node

    # if we have a data volume, we are upgrading/restarting
    elif [ -d "$ETCD_DATA_DIR/member" ]; then
        restart_node

    # if this member is already registered to the cluster but no data volume, we are recovering
    elif [ "$(etcdctln member list | grep $NAME)" != "" ]; then
        recover_node

    # if the cluster is not running and our index is in range, bootstrap
    elif [ "$(get_state)" != "RUNNING" ] && [ "$(($SERVICE_INDEX <= $MIN_SCALE))" == "1" ]; then
        bootstrap_node

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
