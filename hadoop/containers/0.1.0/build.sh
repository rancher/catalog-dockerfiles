#!/bin/bash

cd $(dirname $0)
DOCKER_NAMESPACE=${1:-""}
PUSH=${2:-"false"}
TAG=${TAG:-"dev"}

for i in $(ls -d */); do
    pushd ./$i >/dev/null
    echo "Building: docker build --rm -t $DOCKER_NAMESPACE/$(basename $(pwd)):${TAG} ."
    docker build --rm -t $DOCKER_NAMESPACE/$(basename $(pwd)):${TAG} .

    if [ "${PUSH}" = "true" ]; then
        docker push ${DOCKER_NAMESPACE}/$(basename $(pwd)):${TAG}
    fi

    popd >/dev/null
done
