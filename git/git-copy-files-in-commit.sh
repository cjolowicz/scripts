#!/bin/bash

set -euo pipefail

if [ $# -eq 0 ]
then
    echo "usage: $(basename $0) destdir [commit]"
    exit
fi

destdir=$1
shift

commit=HEAD

if [ $# -gt 0 ]
then
    commit=$1
    shift
fi

mkdir -p $destdir
git show --pretty= --name-only $commit | xargs tar -c | tar -xC $destdir
