#!/bin/bash

bindir=$HOME/.local/bin

mkdir -p $bindir

for file ; do
    file="$(realpath "$file")"
    name="$(basename "$file")"
    name="${name%.*}"

    ln -s "$file" "$bindir"/"$name"
done
