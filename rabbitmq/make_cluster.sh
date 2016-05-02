#!/bin/bash

CONTAINER_ZERO=$(curl rancher-metadata/latest/self/service/containers/0/name)

if [ $HOSTNAME = $CONTAINER_ZERO ]; then
	echo Started first RabbitMQ container of the service: $CONTAINER_ZERO
else
	echo Clustering with $CONTAINER_ZERO

	rabbitmqctl stop_app \
	&& rabbitmqctl join_cluster rabbit@$CONTAINER_ZERO \
	&& rabbitmqctl start_app

fi

