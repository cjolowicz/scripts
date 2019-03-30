#!/bin/bash
# Based on: http://mmorejon.github.io/en/blog/docker-swarm-with-docker-machine-scripts/

set -euo pipefail

nmanagers=1
nworkers=3

leader=$leader
managers=node{1..$nmanagers}
workers=node{$((nmanagers + 1))..$((nmanagers + nworkers))}

echo "### Creating nodes ..."
for node in ${managers[@]} ${workers[@]}
    docker-machine create --driver=virtualbox $node
done

leader_ip=$(docker-machine ip $leader)

echo "### Initializing Swarm ..."
eval $(docker-machine env $leader)
docker swarm init --advertise-addr $leader_ip

manager_token=$(docker swarm join-token --quiet manager)
worker_token=$(docker swarm join-token --quiet worker)

echo "### Joining managers ..."
for node in ${managers[@]} ; do
    if [ $node != $leader ]
    then
        eval $(docker-machine env $node)
        docker swarm join --token $manager_token $leader_ip:2377
    fi
done

echo "### Joining workers ..."
for node in ${workers[@]} ; do
    eval $(docker-machine env $node)
    docker swarm join --token $worker_token $leader_ip:2377
done
