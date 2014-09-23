#!/bin/bash

status=0

mqroot="$(hg root --mq)" || exit 1

if [ -t 1 ] ; then
    viewer=(colordiff)
    pager=(env LESS='FSRX' less)
else
    viewer=(cat)
    pager=(cat)
fi

for patch ; do
    if ! hg qseries | fgrep --quiet "$patch" ; then
        echo "$patch: unknown patch" >&2
        status=1
        continue
    fi

    file="$mqroot/$patch"

    if [ ! -f "$file" ] ; then
        patch=$(hg qseries | grep --max-count=1 "$patch")

        file="$mqroot/$patch"
    fi

    if [ ! -f "$file" ] ; then
        echo "$file: no such file" >&2
        status=1

        continue
    fi

    echo "changeset: $patch"
    "${viewer[@]}" < "$file"
done |
"${pager[@]}"

exit $status
