#!/bin/bash
DIG=/opt/rancher/bin/dig

function cluster_init {
	sleep 10
	MYIP=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1 |  sed -n 2p)
	$DIG A $MONGO_SERVICE_NAME +short > ips.tmp
	mongo --eval "printjson(rs.initiate())"
	for member in $(cat ips.tmp); do
		if [ $member != $MYIP ]; then
			mongo --eval "printjson(rs.add('$member:27017'))"
			sleep 5
		fi
	done

}

function find_master {
	$DIG A $MONGO_SERVICE_NAME +short > ips.tmp
	for IP in $(cat ips.tmp); do
		IS_MASTER=`mongo --host $IP --eval "printjson(db.isMaster())" | grep 'ismaster'`
		if echo $IS_MASTER | grep "true"; then
			return 0
		fi
	done
	return 1
}
# Script starts here
# wait for mongo to start
while [ `$DIG A $MONGO_SERVICE_NAME +short | wc -l` -lt 3 ]; do
	echo 'mongo instances are less than 3.. waiting!'
	sleep 5
done

# Wait until all services are up
sleep 10
find_master
if [ $? -eq 0 ]; then
	echo 'Master is already initated.. nothing to do!'
else
	echo 'Initiating the cluster!'
	cluster_init
fi
