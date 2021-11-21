#!/bin/bash

set -euo pipefail

command=

if [ $# -gt 0 ]
then
    case $1 in
        --rebase)
            command=rebase
            ;;

        --cherry-pick)
            command=cherry-pick
            ;;
    esac
fi

if [ -n "$command" ]
then
    while :
    do
        if $0 && GIT_EDITOR=: git $command --continue
        then
            break
        fi
    done
    exit
fi

git restore --worktree --staged poetry.lock
poetry lock --no-update
git add poetry.lock
