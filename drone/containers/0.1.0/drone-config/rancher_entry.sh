#!/bin/sh

while [ ! -e /etc/drone/dronerc ]; do 
    sleep 1
done

source /etc/drone/dronerc

exec /drone_static
