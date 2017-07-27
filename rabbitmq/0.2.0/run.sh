#!/bin/bash

set -e

exec /docker-entrypoint.sh rabbitmq-server
