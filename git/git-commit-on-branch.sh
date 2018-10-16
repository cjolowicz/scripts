#!/bin/bash

set -e

case $1 in
    '' | '-'*)
        branch=master
        ;;

    *)
        branch="$1"
        shift
        ;;
esac

current=$(git rev-parse --abbrev-ref HEAD)

git stash
git checkout $branch
git stash pop
git commit "$@"
git checkout $current
git rebase $branch
