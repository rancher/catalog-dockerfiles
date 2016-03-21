#!/bin/bash

. /opt/rancher/common.sh

echo "Waiting for all service containers to start..."
giddyup service wait scale --timeout=1200

echo "Containers are starting..."

SELF_NAME=$(curl -s -H 'Accept: application/json' ${META_URL}/self/container| jq -r .name)

IP_METHOD=get_container_primary_ip
if [ "$1" = "host" ]; then
    IP_METHOD=get_host_name
fi

peer_probe()
{
    peer_wait_hosts
    while true; do
        PEER_COUNT=$(gluster pool list|grep -v UUID|wc -l)
        if [ "$(giddyup service scale)" -ne "${PEER_COUNT}" ]; then
            echo "Unprobed nodes detected"
            peer_probe_hosts
        fi
        sleep 15
    done
}

peer_wait_hosts()
{
    ready=false
    while [ "$ready" != true ]; do
        echo "waiting for the daemons"
        sleep 5
        ready=true
        for peer in $(giddyup service containers -n); do
            IP=$(${IP_METHOD} ${peer})
            timeout $TCP_TIMEOUT bash -c ">/dev/tcp/$IP/$DAEMON_PORT"
            if [ "$?" -ne "0" ]; then
                echo "Peer $peer is not ready"
                ready=false
            fi
        done
    done
}

peer_probe_hosts()
{
    for peer in $(giddyup service containers --exclude-self -n);do
        IP=$(${IP_METHOD} ${peer})
        echo gluster peer probe ${IP}
        gluster peer probe ${IP}
        sleep .5
    done
}

random_sleep()
{
    SLEEP_TIME=$RANDOM
    let "SLEEP_TIME %= 30"
    sleep ${SLEEP_TIME}
}

probe_election()
{
    while true; do
        echo "Checking leader status"
        giddyup leader check
        if [ "$?" == "0" ]; then
            echo "Elected as leader"
            peer_probe
        fi
        random_sleep
    done
}

probe_election
