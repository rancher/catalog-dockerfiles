#!/bin/sh

cp /run.sh /opt/rancher/bin/

if [[ -v ALTERNATE_CONF ]]; then 
    echo "Custom template found: overriding internal template";
    printenv ALTERNATE_CONF > /etc/confd/templates/rabbitmq.tmpl; 
fi

exec /confd $@ $CONFD_ARGS
