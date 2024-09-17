#!/bin/bash

baseurl=https://github.com
srcdir=$HOME/Code/github.com

for repository
do
    repository="${repository#https://github.com/}"

    git clone --recurse-submodules $baseurl/$repository.git $srcdir/$repository
done
