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
branch=$(git symbolic-ref --short HEAD)
upstream=$(git for-each-ref --format='%(upstream)' "refs/heads/$branch")

if [ "$branch" != $default ]
then
    git switch $default
fi

git fetch --prune --all
git merge --ff-only

if $delete
then
    if [ "$branch" = "$default" ]
    then
        echo "refusing to delete default branch $branch" >&2
    elif [ -z "$upstream" ]
    then
        echo "refusing to delete non-tracking branch $branch" >&2
    elif git show-ref --verify --quiet "$upstream"
    then
        echo "refusing to delete branch $branch: upstream $upstream still exists" >&2
    else
        git branch --delete --force $branch
    fi
fi
