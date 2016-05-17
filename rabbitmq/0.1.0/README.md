RabbitMQ 3.6.1 Rancher Docker image
===
**TO BE UPDATED**

This template creates and scales out a simple rabbitmq-3.6.1 cluster.

# How it works
The entrypoint runs a `supervisor` that controls two services:
* `rabbitmq-server` original script in parent image's entrypoint that starts the RabbitMQ instance
* `make_cluster.sh` detects the first node in the cluster through rancher metadata and calls the `stop_app`, `join_cluster`, `start_app` sequence in order to add the node to the cluster, if it's not the first container

After deploying the first container, you can scale the service adding new container via Rancher UI.

It includes a Load Balancer that publishes 15672 and 5672 ports (the second could be avoided if the environment is fully containerized).

# TODO
* Scale down does not remove node from cluster, therefore there will still be a unreachable node
* Issues adding and removing nodes
* Issues stopping and starting the stack after adding and removing node
* ERLANG_COOKIE via shared volume?
* confd to tune config?
