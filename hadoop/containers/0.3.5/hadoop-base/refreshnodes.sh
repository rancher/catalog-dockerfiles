#!/bin/bash

export JAVA_HOME=${JAVA_HOME}
export PATH=/usr/local/hadoop-${HADOOP_VERSION}/bin:$PATH

if [ "${1}" = "hdfs" ]; then
    su -c "JAVA_HOME=${JAVA_HOME} /usr/local/hadoop-${HADOOP_VERSION}/bin/hdfs dfsadmin -refreshNodes" hdfs
elif [ "${1}" = "yarn" ]; then
    su -c "JAVA_HOME=${JAVA_HOME} /usr/local/hadoop-${HADOOP_VERSION}/bin/yarn rmadmin -refreshNodes" yarn
else
    echo "Need to specify 'hdfs' or 'yarn'"
fi
