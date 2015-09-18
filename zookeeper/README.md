# (Alpha) Zookeeper Service


This compose file will create a three node Zookeeper cluster. It is designed to run on Rancher and consume the Rancer Metadata service. 


### Usage

This compose file will bring up a cluster of Zookeeper clusters that make it simple to get the unique ID and IP addresses of the nodes in the cluster. 

In bootstrapping this template though, you need to bring the service up by running:

`rancher-compose -p zookeeper up`

This will create the three nodes, but given the way the metadata service currently works, nodes 1 and 2 will not have all the host/container entries.

In order for the configuration to be consistent, you need to run:

`rancher-compose -p zookeeper restart`

After that, the service should be configured properly for use.


### Metadata

The zookeeper-config service is using a rancher build confd binary.

It makes use of the following keys:

/self/container/create_index - The index of the container as it was created in the service.

/self/service/containers - A list of all container names in the service.

/containers/<name>/create_index - the index of the container as it was created in the service.

/containers/<name>/primary_ip - The primary IP (assigned by Rancher) of the container.