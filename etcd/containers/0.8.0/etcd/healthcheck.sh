#!/bin/bash

export PATH=/usr/local/bin:$PATH

if ! etcdctl cluster-health | grep $(giddyup ip myip)|grep 'got\ healthy' ; then
    exit 1
fi

exit 0
