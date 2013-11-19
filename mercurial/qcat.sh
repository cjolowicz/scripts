#!/bin/bash

status=0

hgroot="$(hg root)" || exit 1

for patch ; do
    file="$hgroot/.hg/patches/$patch"

    if ! [ -f "$file" ] ; then
        echo "$file: no such file" >&2
        status=1
        continue
    fi

    if ! hg qseries | grep -q "^$patch\$" ; then
        echo "$patch: unknown patch" >&2
        status=1
        continue
    fi

    echo "changeset: $patch"
    colordiff < "$file"
done |
LESS='FSRX' less

exit $status
