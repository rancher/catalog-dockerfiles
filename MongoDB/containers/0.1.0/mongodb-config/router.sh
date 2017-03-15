#!/bin/bash

if [ -n "$CATTLE_SCRIPT_DEBUG" ]; then 
	set -x
fi

GIDDYUP=/opt/rancher/bin/giddyup

# Script starts here
# get mongo config server IPs
CONFDB=$($GIDDYUP ip stringify --source "dns" --use-agent-names mongo-config)

mongos --configdb $CONFDB
