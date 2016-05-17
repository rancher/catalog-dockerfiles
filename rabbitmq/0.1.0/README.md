RabbitMQ 3.6.1 Rancher Docker image
===
This template creates and scales out a simple rabbitmq-3.6.1 cluster.

# How it works
The entrypoint calls `confd` to create `/etc/rabbitmq/rabbitmq.config` file; in the `cluster_nodes` directive lists all the running rabbitmq containers so that the node connects to the others and creates or joins the cluster at startup time.

After deploying the first container, you can scale the service adding new container via Rancher UI.

To access the management interface, point a balancer on the 15672 port of this service.

# TODO
* Scale down does not remove node from cluster, therefore there will still be a unreachable node
* Issues adding and removing nodes
* Issues stopping and starting the stack after adding and removing node
* ERLANG_COOKIE could be passed via shared volume
* include more common parameters in config
