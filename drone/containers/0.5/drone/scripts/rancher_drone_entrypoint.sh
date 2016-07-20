#!/bin/bash

if [ 'agent' == "$1" ] || [ 'server' == "$1" ]; then
  echo "$0: Starting drone in $1 mode..."
else
  echo "$0: Must specify mode of 'agent' or 'server'." >&2 ; exit -1
fi

while [ ! -e /etc/drone/dronerc ]; do 
    sleep 1
done

if [ -n "${DEBUG}" ]; then
    echo "Contents of /etc/drone/dronerc..."
    cat /etc/drone/dronerc
fi

source /etc/drone/dronerc

exec /drone_static $1
