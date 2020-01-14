#!/bin/bash

set -euo pipefail

volume=$1
shift

host1=$1
shift

host2=$1
shift

image=alpine

options=(
    --rm
    --volume=$volume:/volume
    --workdir=/volume
)

ssh $host1 docker run "${options[@]}" $image tar c -f - . |
    ssh $host2 docker run "${options[@]}" --interactive $image tar x -f - -p -v
