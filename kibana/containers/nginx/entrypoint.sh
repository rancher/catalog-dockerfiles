#!/bin/bash

while [ ! -f "/etc/nginx/conf.d/nginx.conf" ]; do
    sleep 1
done

exec "$@"
