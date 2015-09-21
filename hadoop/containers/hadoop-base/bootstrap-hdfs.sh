#!/bin/bash

export PATH=/usr/local/hadoop-${HADOOP_VERSION}/bin:$PATH

start() {
    echo "starting setup of: ${1}..."
}

end(){
    echo "Finished setting up: ${1}..."
}

# Mapreduce area
start "/tmp/mapred"
hdfs dfs -mkdir -p /tmp/mapred
hdfs dfs -chown mapred:hadoop /tmp/mapred
hdfs dfs -chmod 1750 /tmp/mapred
end "/tmp/mapred"

start "/tmp/hadoop-yarn"
hdfs dfs -mkdir -p /tmp/hadoop-yarn
hdfs dfs -chown mapred:hadoop /tmp/hadoop-yarn
hdfs dfs -chmod 1775 /tmp/hadoop-yarn
end "/tmp/hadoop-yarn"

start "/tmp/logs"
hdfs dfs -mkdir -p /tmp/logs
hdfs dfs -chown yarn:hadoop /tmp/hadoop-yarn
hdfs dfs -chmod 1775 /tmp/hadoop-yarn
end "/tmp/logs"

start "/users/hadoop"
hdfs dfs -mkdir -p /users/hadoop
hdfs dfs -chown hadoop:hadoop /users/hadoop
end "/users/hadoop"
