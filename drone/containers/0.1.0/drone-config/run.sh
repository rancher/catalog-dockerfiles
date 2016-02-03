#!/bin/bash

if [ ! -e /opt/rancher ]; then
    mkdir -p /opt/rancher
fi

cp /rancher_entry.sh /opt/rancher

exec /confd -backend=rancher -prefix=/2015-07-25
