#!/bin/bash

set -e

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "usage: $prog [options]
Fold the two top-most patches { A B } into A.

options:
    -h, --help      Display this message.

This program performs a fold of two patches { A B } using the
following procedure:

    [1]  { A B }  hg qrefresh -m ''
    [2]  { A   }  hg qpop
    [3]  { A'  }  hg qfold B

This is equivalent to a simple fold of A and B, except that the patch
metainformation, such as the filename and the description, is taken
only from A."
}

### command line #######################################################

bad_option () {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
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

### main ###############################################################

aname=$(hg qprev)
bname=$(hg qtop)

hg qrefresh -m ''
hg qpop
hg qfold $bname
