#!/bin/bash

while [ ! -f /opt/rancher/giddyup ]; do 
    echo "Waiting for the yehaw scene..."
    sleep .5
done

exec /opt/rancher/giddyup leader forward --src-port 3307 --dst-port 3306
