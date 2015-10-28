# Kafka Service

This compose file will create a three node Kafka cluster. It is designed to run on Rancher and consume the Rancer Metadata service.

### Usage

This compose file will bring up a cluster of Kafka nodes that make it simple to get the unique ID and IP addresses of the nodes in the cluster.

In bootstrapping this template though, you need to bring the service up by running:

`rancher-compose -p kafka up`

### Metadata

The kafka-conf service is using a rancher build confd binary.

It makes use of the following keys:

/self/container/create_index - The index of the container as it was created in the service.

/services/zookeeper/containers - A list of all container names in the zookeeper service.

/containers/<name>/primary_ip - The primary IP (assigned by Rancher) of the zookeeper containers.

### Author
Matteo Cerutti - matteo.cerutti@hotmail.co.uk
