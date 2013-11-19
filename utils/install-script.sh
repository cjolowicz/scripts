#!/bin/bash

bindir=$HOME/bin

for file ; do
    file="$(realpath "$file")"
    name="$(basename "$file")"
    name="${name%.*}"

    ln -s "$file" "$bindir"/"$name"
done
