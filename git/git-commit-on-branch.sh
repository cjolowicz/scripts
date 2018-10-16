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

git checkout $branch
git commit "$@"
git checkout $current
git rebase $branch
