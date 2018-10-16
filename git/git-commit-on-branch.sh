#!/bin/bash

set -e

if [ $# -gt 0 ]
then
    branch="$1"
    shift
else
    branch=master
fi

current=$(git rev-parse --abbrev-ref HEAD)

git checkout $branch
git commit "$@"
git checkout $current
git rebase $branch
