#!/bin/bash

dir="$(readlink -m "$1")"
file="$(readlink -m "$2")"
path=.

while [ "${file#$dir}" = "$file" ]
do
    dir="$(dirname "$dir")"
    path="$path/.."
done

if [ "$file" != "$dir" ]
then
    path="$path/${file#$dir}"
fi

sed -e 's:/\+:/:g' -e 's:^./::' -e 's:/$::' <<< "$path"
