#!/bin/bash
#
# List all files in the stow directory which are not linked to from
# the target directory.

stowdir=.
targetdir=..

find $stowdir -mindepth 1 -maxdepth 1 -type d -name '[^.]*' |
while read dir ; do
    ( cd $dir && find -type f ) |
    while read file ; do
        [ -L $targetdir/$file ] || echo $dir/$file
    done
done
