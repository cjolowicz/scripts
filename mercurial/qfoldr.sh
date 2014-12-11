#!/bin/bash

set -e

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "usage: $prog [options]
Fold the two top-most patches { A B } into B.

options:
    -h, --help      Display this message.

This program performs a fold of two patches { A B } using the
following procedure:

    [1]  { A 0   }  hg qrefresh -X .
    [2]  { A 0 B }  hg qnew B
    [3]  { A     }  hg qgoto A
    [3]  { A     }  hg qrefresh -m ''
    [3]  {       }  hg qpop
    [3]  { 0     }  hg qpush --move 0
    [4]  { A'    }  hg qfold A
    [5]  { B'    }  hg qfold B

This is equivalent to a simple fold of A and B, except that the patch
metainformation, such as the filename and the description, is taken
only from B."
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
cname=TMP-$bname

hg qrefresh -X .
hg qnew $cname
hg qgoto $aname
hg qrefresh -m ''
hg qpop
hg qpush --move $bname
hg qfold $aname $cname
