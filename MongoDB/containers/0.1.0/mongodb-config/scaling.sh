#!/bin/bash
sleep 5
DIG=/opt/rancher/bin/dig

function scaleup {
	MYIP=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1 |  sed -n 2p)
	$DIG A $MONGO_SERVICE_NAME +short > ips.tmp
	for IP in $(cat ips.tmp); do
		IS_MASTER=$(mongo --host $IP --eval "printjson(db.isMaster())" | grep 'ismaster')
		if echo $IS_MASTER | grep "true"; then
			mongo --host $IP --eval "printjson(rs.add('$MYIP:27017'))"
			return 0
		fi
	done
	return 1
}

# Script starts here
if [ $($DIG A $MONGO_SERVICE_NAME +short | wc -l) -gt 3 ]; then
	scaleup
fi
