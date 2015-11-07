#!/bin/bash

export JAVA_HOME=${JAVA_HOME}
export PATH=/usr/local/hadoop-${HADOOP_VERSION}/bin:$PATH

if [ "${1}" = "hdfs" ]; then
    hdfs dfsadmin -refreshNodes
elif [ "${1}" = "yarn" ]; then
    yarn rmadmin -refreshNodes
else
    echo "Need to specify 'hdfs' or 'yarn'"
fi
