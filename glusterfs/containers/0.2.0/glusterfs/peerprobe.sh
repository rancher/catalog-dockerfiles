#!/bin/bash

. /opt/rancher/common.sh

echo "Waiting for all service containers to start..."
/giddyup service wait scale --timeout=1200
echo "Containers are starting..."

SELF_NAME=$(curl -s -H 'Accept: application/json' ${META_URL}/self/container| jq -r .name)

IP_METHOD=get_container_primary_ip
if [ "$1" = "host" ]; then
    IP_METHOD=get_host_name
fi

# let the services come up
echo "Waiting for Gluster Daemons to come up"
sleep 30

peer_probe_hosts()
{    
    for peer in $(/giddyup service containers --exclude-self -n);do
        IP=$(${IP_METHOD} ${peer})
        echo gluster peer probe ${IP}
        gluster peer probe ${IP}
        sleep .5
    done
}

random_sleep()
{
    SLEEP_TIME=$RANDOM
    let "SLEEP_TIME %= 15"
    sleep ${SLEEP_TIME}
}


while true; do
    PEER_COUNT=$(gluster pool list|grep -v UUID|wc -l)
    if [ "$(/giddyup service scale)" -ne "${PEER_COUNT}" ]; then
        # avoid possible race condition...
        random_sleep
        peer_probe_hosts
    fi
    sleep 15
done
