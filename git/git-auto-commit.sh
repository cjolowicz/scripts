#!/bin/bash

set -euo pipefail

case $1 in
    --push)
        push=true
        shift
        ;;

    *)
        push=false
        ;;
esac

if [ $# -eq 0 ]
then
    options=(
        --recursive
        --print0
        --event Created
        --event Updated
        --event Removed
        --event Renamed
        --event MovedFrom
        --event MovedTo
        --event AttributeModified
    )
    # Use --max-args=1 to avoid buffering.
    exec fswatch "${options[@]}" . |
        xargs --max-args=1 --null git ls-files -z |
        xargs --max-args=1 --null --no-run-if-empty "$0"
fi

set -x

for file
do
    message="$(realpath --relative-to=. "$file")"
    git commit --message="$message" "$file"
done

if $push
then
    git push
fi
