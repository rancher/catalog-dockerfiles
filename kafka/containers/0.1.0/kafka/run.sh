#!/bin/bash

# print environment for debugging
env

# some defaults
KAFKA_HOME=${KAFKA_HOME:-/opt/kafka}
KAFKA_CONFIG_FILE=$KAFKA_HOME/config/server.properties

broker_id_config="$KAFKA_HOME/conf.d/broker_id"
while [ ! -s $broker_id_config ]; do
  echo "Waiting for $broker_id_config to appear"
  sleep 1
done
broker_id=$(cat $broker_id_config)
echo "broker.id = $broker_id" > $KAFKA_CONFIG_FILE

zookeeper_connect_config="$KAFKA_HOME/conf.d/zookeeper_connect"
while [ ! -s $zookeeper_connect_config ]; do
  echo "Waiting for $zookeeper_connect_config to appear"
  sleep 1
done
zookeeper_connect=$(cat $zookeeper_connect_config | xargs | tr ' ' ',')
echo "zookeeper.connect = $zookeeper_connect" >> $KAFKA_CONFIG_FILE

export KAFKA_CONFIG_PORT=${KAFKA_CONFIG_PORT:-9092}

if [ -z "$KAFKA_CONFIG_LOG_DIRS" ]; then
  echo "Must export KAFKA_CONFIG_LOG_DIRS environment variable" >&2
  exit 1
else
  # make sure they are comma separated
  export KAFKA_CONFIG_LOG_DIRS=$(echo "$KAFKA_CONFIG_LOG_DIRS" | tr ' ' ',')
fi

export KAFKA_CONFIG_HOST_NAME=${KAFKA_CONFIG_HOST_NAME:-$(hostname)}

for v in `env | egrep '^KAFKA_CONFIG_'`; do
  name=$(echo "$v" | cut -d '=' -f 1 | sed -e 's/KAFKA_CONFIG_//' | tr '[A-Z]' '[a-z]' | tr '_' '.')
  value=$(echo "$v" | cut -d '=' -f 2)
  echo "$name = $value" >> $KAFKA_CONFIG_FILE
done

echo "Starting kafka .."
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_CONFIG_FILE &
pid=$!

# wait for kafka to start up
while ! netstat --listen --numeric --tcp | awk '{ print $4 }' | egrep -q ":$KAFKA_CONFIG_PORT$"; do
  # make sure we do not wait forever though
  kill -0 $pid &>/dev/null || { echo "Kafka shut down unexpectedly"; exit 1; }
  echo "Waiting for kafka to bind to TCP $KAFKA_CONFIG_PORT"
  sleep 1
done

if [ -n "$KAFKA_CREATE_TOPICS" ]; then
  for topic in $KAFKA_CREATE_TOPICS; do
    # check if the syntax if correct first
    if [[ $topic =~ ^(.*?):([0-9]+):([0-9]+)$ ]]; then
      name=${BASH_REMATCH[1]}
      partition=${BASH_REMATCH[2]}
      replication_factor=${BASH_REMATCH[3]}
      echo "$KAFKA_HOME/bin/kafka-topics.sh --create --zookeeper $zookeeper_connect --replication-factor $replication_factor --partition $partition --topic $name"
    else
      echo "Failed to create topic '$topic', invalid syntax (should be <name>:<partition>:<replication_factor>)" >&2
    fi
  done
fi

wait $pid
