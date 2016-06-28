#!/bin/bash
if [ "$RANCHER_DEBUG" == "true" ]; then set -x; fi

DISCOVERY=http://discovery:6666
UUID=6c007a14875d53d9bf0ef5a6fc0257c817f0fb84

IP=$(giddyup ip myip)
# TODO (llparse) when scale_policy enabled, scale value is always 1. 
# We need to check metadata for scale policy info once it is available
SCALE=$(giddyup service scale etcd)

META_URL="http://rancher-metadata.rancher.internal/2015-12-19"
STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
SERVICE_INDEX=$(wget -q -O - ${META_URL}/self/container/service_index)
NAME=etcd${SERVICE_INDEX}

etcdctld() {
    etcdctl --no-sync --endpoints $DISCOVERY $@
}

bootstrap() {
    echo Waiting for discovery node to become ready
    giddyup probe $DISCOVERY/health --loop --min 1s --max 60s --backoff 1.1

    if [ "$(etcdctl get _state)" != "RUNNING" ]; then
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
            giddyup probe http://etcd:2379/health --loop --min 1s --max 60s --backoff 1.1
        fi

        echo Setting cluster state to RUNNING
        if [ "$(etcdctl set _state RUNNING)" != "RUNNING" ]; then
            echo ERROR: Could not set cluster state
            exit 1
        fi
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
    echo Waiting for discovery node to become ready
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
    standalone_bootstrap &
    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        --initial-cluster etcd1=http://${IP}:2380 \
        --initial-cluster-state new
}

standalone_bootstrap() {
    echo Waiting for standalone node to start
    giddyup probe http://${STACK_NAME}_etcd_${SERVICE_INDEX}:2379/health --loop --min 1s --max 1s
    etcdctl set _state RUNNING
}

# restarts and upgrades
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
    # We can almost use giddyup here, need service index templating {{service_index}}
    # giddyup ip stringify --prefix etcd{{service_index}}=http:// --suffix :2380
    # etcd1=http://10.42.175.109:2380,etcd2=http://10.42.58.73:2380,etcd3=http://10.42.96.222:2380
    for container in $(wget -q -O - ${META_URL}/services/etcd/containers); do
        meta_index=$(echo $container | tr '=' '\n' | head -n1)
        service_index=$(wget -q -O - ${META_URL}/services/etcd/containers/${meta_index}/service_index)

        # simulate step-scale policy by ignoring service_indeces greater than our own (except during recovery)
        if [ "$RECOVERING" != "true" ] && [ "$(($service_index > $SERVICE_INDEX))" == "1" ]; then
            continue
        fi

        cip=$(wget -q -O - ${META_URL}/services/etcd/containers/${meta_index}/primary_ip)
        if [ "$cluster" != "" ]; then
            cluster=${cluster},
        fi
        cluster=${cluster}etcd${service_index}=http://${cip}:2380
    done

    etcdctl member add $NAME http://${IP}:2380

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
    oldnode=$(etcdctl member list | grep $NAME | tr ':' '\n' | head -1)

    # remove the old node
    etcdctl member remove $oldnode

    # start the new node
    RECOVERING=true
    runtime_node
}

node() {
    if [ "$SERVICE_INDEX" == "1" ]; then
        standalone_node
    else
        # Wait for nodes with smaller service index to become healthy
        if [ "$(($SERVICE_INDEX > 1))" == "1" ]; then
            echo Waiting for lower index nodes to all be active
            for i in $(seq 1 $(($SERVICE_INDEX - 1))); do
                giddyup probe http://${STACK_NAME}_etcd_${i}:2379/health --loop --min 1s --max 60s --backoff 1.1
            done
        fi    

        # if we have a data volume, we are upgrading/restarting
        if [ -d "$ETCD_DATA_DIR/member" ]; then
            restart_node

        # if this member is already registered to the cluster but no data volume, we are recovering
        elif [ "$(timeout -t10 etcdctl member list | grep $NAME)" != "" ]; then
            recover_node

        # we are scaling up
        else
            runtime_node
        fi
    fi

    # TODO (llparse) once we have scale_policy metadata access
    #if [ min_scale_policy > 1 && !running]; then
    #    bootstrap_node
    #fi
}

if [ $# -eq 0 ]; then
    echo No command specified, running in standalone mode.
    standalone_node
else
    eval $1
fi
