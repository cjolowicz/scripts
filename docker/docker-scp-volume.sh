#!/bin/bash

set -euo pipefail

volume=$1
shift

host1=$1
shift

host2=$1
shift

options=(
    --rm
    --volume=$volume:/volume
)

ssh $host1 docker run "${options[@]}" alpine tar c -C /volume -f - . |
    ssh $host2 docker run "${options[@]}" --interactive alpine tar x -C /volume -f - -p -v
