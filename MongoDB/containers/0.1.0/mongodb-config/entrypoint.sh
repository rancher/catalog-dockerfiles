#!/bin/bash

# Check for lowest ID
sleep 10
/opt/rancher/bin/giddyup leader check
if [ "$?" -eq "0" ]; then
    echo "This is the lowest numbered contianer.. Handling the initiation."
    /opt/rancher/bin/initiate.sh $@
else

# Run the scaling script
/opt/rancher/bin/scaling.sh &

# Start mongodb
if [ $? -ne 0 ]
then
echo "Error Occurred.."
fi

set -e

if [ "${1:0:1}" = '-' ]; then
	set -- mongod "$@"
fi

if [ "$1" = 'mongod' ]; then
	chown -R mongodb /data/db

	numa='numactl --interleave=all'
	if $numa true &> /dev/null; then
		set -- $numa "$@"
	fi

	exec gosu mongodb "$@"
fi

exec "$@"

fi
