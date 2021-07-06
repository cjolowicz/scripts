#!/bin/bash

set -euo pipefail

rebase=false

if [ $# -gt 0 ]
then
    case $1 in
        --rebase)
            rebase=true
            ;;
    esac
fi

if $rebase
then
    while :
    do
        if $0 && GIT_EDITOR=: git rebase --continue
        then
            break
        fi
    done
    exit
fi

git restore --worktree --staged poetry.lock
poetry lock --no-update
git add poetry.lock
