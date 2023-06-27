#!/bin/bash

baseurl=https://github.com
srcdir=$HOME/Code/github.com

for repository
do
    git clone --recurse-submodules $baseurl/$repository.git $srcdir/$repository
done
