#!/bin/bash

# Installing dnsutils and jq
echo "deb http://http.debian.net/debian wheezy-backports main" | tee /etc/apt/sources.list.d/wheezy-backports.list > /dev/null
echo "deb http://security.debian.org/ wheezy/updates main contrib non-free " | tee /etc/apt/sources.list.d/wheezy-security.list > /dev/null
echo "deb-src http://security.debian.org/ wheezy/updates main contrib non-free" | tee /etc/apt/sources.list.d/wheezy-security.list > /dev/null
apt-get -q update > /dev/null
apt-get install -qqy dnsutils jq > /dev/null 2>&1

# Check for lowest ID
/opt/rancher/bin/lowest_idx.sh
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
