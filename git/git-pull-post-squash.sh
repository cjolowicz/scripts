#!/bin/bash
usage="\
usage: $(basename $0) [-D | --delete]

1. Switch to the default branch.
2. Fetch all remotes and prune branches.
3. Fast-forward the default branch.
4. Remove the old topic branch.
"

set -euo pipefail

delete=false

if [ $# -gt 0 ]
then
    case $1 in
        -D | --delete)
            delete=true
            ;;
        *)
            echo "$usage"
            exit 1
            ;;
    esac
fi

default=main
branch=$(git rev-parse --abbrev-ref HEAD)

if [ "$branch" != $default ]
then
    git switch $default
fi

git fetch --prune --all
git merge --ff-only

if $delete && [ "$branch" != $default ]
then
    git branch --delete --force $branch
fi
