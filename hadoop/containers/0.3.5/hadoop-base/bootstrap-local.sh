#!/bin/bash

export PATH=/usr/local/hadoop-${HADOOP_VERSION}/bin:$PATH

start() {
    echo "starting setup of: ${1}..."
}

end(){
    echo "Finished setting up: ${1}..."
}

create_local_path() #signature path, user, perms, group 
{
    local path="${1}"
    local user="${2}"
    local perms="${3}"
    local group="${4:-hadoop}"

    start "${path}"
    mkdir -p "${path}"
    chown "${user}:${group}" "${path}"
    chmod "${perms}" "${path}"
    end "${path}"
}

# Temp area
create_local_path "/tmp/hadoop-mapred" "mapred" "1750"
create_local_path "/tmp/hadoop-yarn" "yarn" "1775"
create_local_path "/tmp/logs" "yarn" "1775"
