#!/bin/bash

dir1="$1"
dir2="$2"

tmpdir="$(mktemp -d)"
trap 'rm -rf $tmpdir' 0

list1="$tmpdir"/1
list2="$tmpdir"/2

find "$dir1" -type f -print0 | xargs -0 -n1 md5sum | sort | sed "s,${1//,\\,},a,g" > "$list1"
find "$dir2" -type f -print0 | xargs -0 -n1 md5sum | sort | sed "s,${2//,\\,},b,g" > "$list2"

echo "Identical Files:"
echo
join "$list1" "$list2" | column -t

echo
echo "Only in $dir1:"
echo
join -v 1 "$list1" "$list2" | column -t

echo
echo "Only in $dir2:"
echo
join -v 2 "$list1" "$list2" | column -t
