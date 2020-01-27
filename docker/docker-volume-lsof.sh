#!/bin/bash

set -euo pipefail

volumes=($(docker volume ls --quiet))

for volume in ${volumes+"${volumes[@]}"}
do
    echo "==> Containers using $volume <=="
    echo
    docker ps --filter="volume=$volume"
    echo
done
