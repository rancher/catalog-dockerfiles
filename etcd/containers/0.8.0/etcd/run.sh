#!/bin/bash
if [ "$RANCHER_DEBUG" == "true" ]; then set -x; fi

IP=$(giddyup ip myip)
META_URL="http://rancher-metadata.rancher.internal/2015-12-19"
STACK_NAME=$(wget -q -O - ${META_URL}/self/stack/name)
SERVICE_INDEX=$(wget -q -O - ${META_URL}/self/container/service_index)
NAME=${HOSTNAME}
export ETCDCTL_ENDPOINT=http://etcd.${STACK_NAME}:2379

etcdctln() {

    for i in $(seq 1 10); do 
        giddyup probe http://$(giddyup leader get):2379/health &> /dev/null
        if [ "$?" == "0" ]; then
            break
        fi
        sleep 1
    done

    # throw a hail mary... maybe...
    if ! etcdctl --endpoints http://$(giddyup leader get):2379 $@ ; then
        echo "leader did not take request: $@"
    fi
}


standalone_node() {

    # go defensive and ONLY go standalone if there is no data.
    opts="--initial-cluster-state existing"
    if [ ! -d "${ETCD_DATA_DIR}/member" ] ; then
        opts="--initial-cluster ${NAME}=http://${IP}:2380 --initial-cluster-state new"
    fi

    etcd \
        --name ${NAME} \
        --listen-client-urls http://0.0.0.0:2379 \
        --advertise-client-urls http://${IP}:2379 \
        --listen-peer-urls http://0.0.0.0:2380 \
        --initial-advertise-peer-urls http://${IP}:2380 \
        ${opts}
}

restart_node() {
    # Runtime reconfigure the IP address in case retain_ip isn't set and we are upgrading
    oldnode=$(etcdctln member list | grep "$NAME" | tr ':' '\n' | head -1)
    etcdctln member update $oldnode http://${IP}:2380

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
        container_name=$(wget -q -O - ${META_URL}/self/service/containers/${meta_index}/name)

        # simulate step-scale policy by ignoring service_indeces greater than our own (except during recovery)
        if [ "$(($service_index > $SERVICE_INDEX))" == "1" ]; then
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

node() {
    if giddyup leader check ; then
        standalone_node
    fi

    # if we have a data volume, we are upgrading/restarting
    if [ -d "$ETCD_DATA_DIR/member" ]; then
        restart_node

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
