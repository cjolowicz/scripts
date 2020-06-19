#!/bin/bash

set -euo pipefail

repo=$1
shift

repodir=$HOME/Code/github.com/$repo
basedir=$(dirname $repodir)

mkdir -p $basedir
cd $basedir
gh repo fork --clone=true $repo
echo $repodir
