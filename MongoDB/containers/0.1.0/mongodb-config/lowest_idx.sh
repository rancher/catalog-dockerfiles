#!/bin/bash
###
# Detect if this container has the lowest create ID
###
JQ=/opt/rancher/bin/jq

META_URL="http://rancher-metadata/2015-07-25"

ALLMETA=$(curl -s -H 'Accept: application/json' ${META_URL})
MY_CREATE_INDEX="$(echo ${ALLMETA} | $JQ -r .self.container.create_index)"

get_create_index()
{
    echo $(echo ${ALLMETA}| $JQ -r ".containers[]| select(.name==\"${1}\")| .create_index")
}

SMALLEST="${MY_CREATE_INDEX}"
for container in $(echo ${ALLMETA}| $JQ -r .self.service.containers[]); do
    IDX=$(get_create_index "${container}")
    if [ "${IDX}" -lt "${SMALLEST}" ]; then
        SMALLEST=${IDX}
    fi
done
if [ "${MY_CREATE_INDEX}" -eq "${SMALLEST}" ]; then
  exit 0
fi

exit 1
