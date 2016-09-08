#!/bin/sh

cp /run.sh /opt/rancher/bin/

exec /confd $@ $CONFD_ARGS
