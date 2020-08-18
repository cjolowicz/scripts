#!/bin/bash

set -euo pipefail

volume="$1"
shift

source="$1"
shift

if [ $# -gt 0 ]
then
    destination="$(realpath "$1")"
    shift
else
    destination="$(pwd)"
fi

image=busybox

options=(
    --rm
    --volume="$volume":/volume:ro
    --volume="$destination":/host:rw
    --workdir=/volume
)

command=(
    cp "/volume/${source#/}" "/host"
)

docker run "${options[@]}" $image "${command[@]}"
