#!/bin/bash

infile=$1
outfile=$2
tmpdir=$(mktemp -d)
trap 'rm -rf $tmpdir' 0

function normalize() {
    sed -e '1,/^$/d' -e 's/ *# .*//' -e 's/==/ /' | sort
}

normalize < $outfile > $tmpdir/old

pip-compile --dry-run --upgrade $infile 2>/dev/null | normalize > $tmpdir/new

cd $tmpdir

diff -u old new |
    sed -ne 's/^[+-]//p' |
    sed -e '/^[+-]/d' |
    cut -d' ' -f1 |
    sort |
    uniq > diff

join <(join old diff) <(join new diff) | column -t
