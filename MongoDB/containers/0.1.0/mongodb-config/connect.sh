#!/bin/bash

if [ -n "$CATTLE_SCRIPT_DEBUG" ]; then 
	set -x
fi

GIDDYUP=/opt/rancher/bin/giddyup

function cluster_init {
	sleep 10
	MYIP=$($GIDDYUP ip myip)
	mongo --eval 'cfg = { "_id" : "'${REPLSET_NAME}'", "version" : 1, "members" : [ { "_id" : 0, "host" : "'${MYIP}':27017" } ] };rs.initiate(cfg)'
	for member in $($GIDDYUP ip stringify --delimiter " "); do
		if [ "$member" != "$MYIP" ]; then
			mongo --eval "printjson(rs.add('$member:27017'))"
			sleep 5
		fi
	done

}

function find_master {
	for member in $($GIDDYUP ip stringify --delimiter " "); do
		IS_MASTER=$(mongo --host $member --eval "printjson(db.isMaster())" | grep 'ismaster')
		if echo $IS_MASTER | grep "true"; then
			return 0
		fi
	done
	return 1
}
# Script starts here
# wait for mongo to start
$GIDDYUP service wait scale --timeout 120

# Wait until all services are up
sleep 10
find_master
if [ $? -eq 0 ]; then
	echo 'Master is already initated.. nothing to do!'
else
	echo 'Initiating the cluster!'
	cluster_init
fi
