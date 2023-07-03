#!/bin/bash

set -euo pipefail

if [ $# -eq 0 ]
then
    # Use xargs -n1 to avoid buffering.
    exec fswatch -r0 . | xargs -n1 -0 git ls-files -z | xargs -n1 -0 "$0"
fi

for file
do
    message=$(realpath --relative-to=. "$file")
    git commit --message="$message" "$file"
done
