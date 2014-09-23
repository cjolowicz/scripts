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
following procedure:

    [1]  { A  B  C     }  where C  = -A      (reverse application of A)
    [2]  { A  B  C  A' }  where A' = -C      (reverse application of C)
    [3]  { B' A'       }  where B' = A + B + C          (fold of A B C)

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

start() {
    aname=$(hg qprev)
    adesc="$(hg log -r $aname --template '{desc}')"

    bname=$(hg qtop)
    bdesc="$(hg log -r $bname --template '{desc}')"

    # reverse application of A
    cname=REVERSE-$aname

    hg qnew $cname

    if ! hg log -p -r $aname | patch -d "$hgroot" -p1 -R ; then
        error "resolve conflicts and qrefresh, \`$prog --continue' to resume."
    fi

    hg qrefresh
}

resume() {
    aname=$(hg qapplied | tail -n2 | head -n1)
    adesc="$(hg log -r $aname --template '{desc}')"

    bname=$(hg qprev)
    bdesc="$(hg log -r $bname --template '{desc}')"

    cname=$(hg qtop)
}

finish() {
    # reverse application of C
    dname=REVERSE-$cname

    hg qnew $dname

    if ! hg log -p -r $cname | patch -d "$hgroot" -p1 -R ; then
        error "cannot reverse $cname"
    fi

    hg qrefresh

    # fold of A + B + C into B'
    hg qgoto $aname
    hg qfold $(hg qunapplied | head -n2)
    hg qrename $bname
    hg qrefresh -m"$bdesc"

    # application of A'
    hg qpush
    hg qrename $aname
    hg qrefresh -m"$adesc"
}

### main ###############################################################

if $continue ; then
    resume
else
    start
fi

finish
