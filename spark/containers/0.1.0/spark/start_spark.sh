#!/bin/bash

export METADATA_URL="http://rancher-metadata/2015-07-25"
. common.sh

role="${1}"
if [ -z "${role}" ]; then
    echo "Need either master or worker as first arg"
    exit 1
fi

while [ ! -f "/etc/spark/spark-env.sh" ]; do
    sleep .5
done

opts=
class="org.apache.spark.deploy.master.Master"
if [ "$role" = "worker" ]; then
    class="org.apache.spark.deploy.worker.Worker"
    opts=$(get_master_string)
fi

if [ "${role}" = "master" ]; then
    export ZK_STRING=$(get_zookeeper_string)
fi


exec /usr/local/spark/bin/spark-class ${class} ${opts}
