#!/bin/bash

set -e

force=no
case $1 in -f | --force)
    force=yes ; shift ;;
esac

if [ $# -ne 2 ] ; then
    echo "usage: $(basename $0) [-f|--force] srcdir destdir" >&2
    exit 2
fi

srcdir="$1"
destdir="$2"

if [ -e "$srcdir"/.hg -a -e "$destdir"/.hg ] ; then
    echo "$(basename $0): refuse to overwrite \`$destdir/.hg'" >&2
    exit 1
fi

srcdir="$(readlink --canonicalize "$srcdir")"

if [ $force = yes ] ; then
    opt=-f
else
    opt=
fi

cp $opt --symbolic-link --recursive --no-target-directory "$srcdir" "$destdir" || status=$?

rm -rf "$destdir"/.hg

exit $status
