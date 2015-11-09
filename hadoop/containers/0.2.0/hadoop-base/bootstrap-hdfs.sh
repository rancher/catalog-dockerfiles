#!/bin/bash

export PATH=/usr/local/hadoop-${HADOOP_VERSION}/bin:$PATH

start() {
    echo "starting setup of: ${1}..."
}

end(){
    echo "Finished setting up: ${1}..."
}

create_hdfs_path() #signature path, user, perms, group 
{
    local path="${1}"
    local user="${2}"
    local perms="${3}"
    local group="${4:-hadoop}"

    start "${path}"
    hdfs dfs -mkdir -p "${path}"
    hdfs dfs -chown "${user}:${group}" "${path}"
    hdfs dfs -chmod "${perms}" "${path}"
    end "${path}"
}

add_hdfs_user() 
{
    start "/user/${1}"
    hdfs dfs -mkdir -p "/tmp/hadoop-${1}"
    hdfs dfs -chown "${1}:hadoop" "/tmp/hadoop-${1}"

    hdfs dfs -mkdir -p "/user/${1}"
    hdfs dfs -chown "${1}:hadoop" "/user/${1}"
    end "/user/${1}"
}

# Temp area
create_hdfs_path "/tmp/mapred" "mapred" "1750"
create_hdfs_path "/tmp/hadoop-yarn" "mapred" "1775"
create_hdfs_path "/tmp/logs" "yarn" "1775"

# Users
add_hdfs_user hadoop
