#!/bin/bash

set -e

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "usage: $prog [options]
Reverse the order of the two top-most patches.

options:
    -c, --continue  Resume after conflict resolution.
    -h, --help      Display this message.

This program reverses the order of two patches { A B } using the
following procedure (simplified):

    [1] reverse application of A

        { A B } => { A B -A }

    [2] reverse application of -A

        { A B -A } => { A B -A A' }

    [3] fold

        { A B -A A' } => { B' A' }

The first step may require manual intervention."
}

### command line #######################################################

bad_option () {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

continue=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -c | --continue) continue=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] || bad_option "$1"

### functions ##########################################################

hgroot="$(hg root)"

error() {
    echo "$prog: $*" >&2
    exit 1
}

reverse() {
    hg log -p -r $1 | patch -d "$hgroot" -p1 -R
}

start() {
    aname=$(hg qprev)
    bname=$(hg qtop)
    cname=REVERSE-$aname
    dname=TMP-$aname

    hg qpop                # { A      | B }
    hg qrefresh -X .       # { 0      | B } -- "0" is a zero patch with A's metainfo
    hg qnew $dname         # { 0 A    | B }
    hg qpop                # { 0      | A B }
    hg qpop                # {        | 0 A B }
    hg qpush --move $dname # { A      | 0 B }
    hg qpush --move $bname # { A B    | 0 }
    hg qnew $cname         # { A B -A | 0 }
    reverse $dname ||
        error "resolve conflicts and qrefresh, \`$prog --continue' to resume."
    hg qrefresh
}

resume() {
    aname=$(hg qapplied | tail -n2 | head -n1)
    bname=$(hg qprev)
    cname=$(hg qtop)
    dname=$(hg qnext)

    [ "$cname" = REVERSE-$aname ] || error "unexpected patch \"$cname\""
    [ "$dname" = TMP-$aname     ] || error "unexpected patch \"$dname\""
}

finish() {
    hg qpush    # { A B -A 0 }
    reverse $cname ||
        error "cannot reverse $cname"
    hg qrefresh # { A B -A A' }
    hg qpop     # { A B -A | A' }
    qfoldl      # { A B'   | A' }
    qfoldr      # { B"     | A' }
    hg qpush    # { B" A' }
}

### main ###############################################################

which qfoldl >/dev/null 2>&1 ||
    error "qfoldl not found"

which qfoldr >/dev/null 2>&1 ||
    error "qfoldr not found"

if $continue ; then
    resume
else
    start
fi

finish
