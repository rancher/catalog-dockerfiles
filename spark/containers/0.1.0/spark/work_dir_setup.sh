#!/bin/bash


echo "Checking /spark/work directory is owned by spark user"
if [ -d "/spark/work" ] && [ ! "$(stat -c %U /spark/work)" = "spark" ]; then
    echo "Directory ["/spark/work"] is not owned by spark, changing owners.."
    chown -R spark:spark /spark/work
fi

echo "work dir setup"
