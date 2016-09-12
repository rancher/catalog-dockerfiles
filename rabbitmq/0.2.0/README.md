RabbitMQ 3.6 Rancher Docker image
===
This template creates and scales out a rabbitmq-3.6 cluster.

# How it works
The entrypoint calls `confd` to create `/etc/rabbitmq/rabbitmq.config` file; in the `cluster_nodes` directive lists all the running rabbitmq containers so that the node connects to the others and creates or joins the cluster at startup time.

After deploying the first container, you can scale the service adding new container via Rancher UI.

To access the management interface, point a balancer on the 15672 port of this service.

## Environment variables
The following environment variables are passed to `confd` in order to set up RabbitMQ's  configuration file:

* `RABBITMQ_CLUSTER_PARTITION_HANDLING`: RabbitMQ's cluster handling setting: default set to `autoheal`
* `RABBITMQ_NET_TICKTIME`: adjusts the frequency of both tick messages and detection of failures: default set to `60`
* `RABBITMQ_ERLANG_COOKIE`: cookie to allow nodes communication: default set to `defaultcookiepleasechange`

Other two variables are available to fine-tune the cluster or test `confd` configuration:

* `ALTERNATE_CONF`: overrides the whole default `confd` RabbitMQ template: default set to empty
* `CONFD_ARGS`: additional `confd` args along with default `--backend rancher --prefix /2015-07-25`: default set to `--interval 5`

