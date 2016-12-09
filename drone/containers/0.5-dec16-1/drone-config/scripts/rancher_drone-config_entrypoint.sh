#!/bin/bash

if [ 'agent' == "$1" ] || [ 'server' == "$1" ]; then
  echo "$0: Starting drone in $1 mode..."
else
  echo "$0: Must specify mode of 'agent' or 'server'." >&2 ; exit -1
fi

confd_cmd='/confd -backend=rancher -prefix=/2015-07-25'

if [ -n "${DEBUG}" ]; then
    extra_confd_opts='-log-level=debug'
    ${confd_cmd} ${extra_confd_opts} -noop -onetime
fi

exec ${confd_cmd} ${extra_confd_opts} -confdir="/etc/confd/$1"
