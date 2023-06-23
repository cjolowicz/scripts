#!/bin/bash
# https://stackoverflow.com/a/9507417/1355754

repo=$1
shift

[ $# -gt 0 ] || set -- HEAD

for commit
do
    git --git-dir="$repo"/.git format-patch -k -1 --stdout $commit | git am -3 -k
done
