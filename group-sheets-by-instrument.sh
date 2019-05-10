#!/bin/bash

for file ; do
    basename="$(basename "$file")"
    name="${basename%.pdf}"
    instrument="${name##* - }"

    mkdir -p "$instrument"
    cp -t "$instrument" "$file"
done
