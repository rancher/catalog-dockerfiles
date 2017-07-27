#!/bin/bash

set -e

exec /usr/local/bin/docker-entrypoint.sh rabbitmq-server
