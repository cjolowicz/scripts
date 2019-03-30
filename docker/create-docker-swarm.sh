#!/bin/bash

set -exuo pipefail

nmanagers=1
nworkers=3

leader=node1
managers=($(seq --format=node%.f $nmanagers))
workers=($(seq --format=node%.f $((nmanagers + 1)) $((nmanagers + nworkers))))

for node in ${managers[@]} ${workers[@]}
do
    docker-machine create --driver=virtualbox $node
done

leader_ip=$(docker-machine ip $leader)

eval $(docker-machine env $leader)
docker swarm init --advertise-addr=$leader_ip

manager_token=$(docker swarm join-token --quiet manager)
worker_token=$(docker swarm join-token --quiet worker)

for node in ${managers[@]:1}
do
    eval $(docker-machine env $node)
    docker swarm join --token=$manager_token $leader_ip:2377
done

for node in ${workers[@]}
do
    eval $(docker-machine env $node)
    docker swarm join --token=$worker_token $leader_ip:2377
done
