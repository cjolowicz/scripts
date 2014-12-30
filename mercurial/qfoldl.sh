#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $prog [options]
Fold the two top-most patches { A B } into A.

options:
    -n, --dry-run   Print commands instead of executing them.
    -v, --verbose   Be verbose.
    -q, --quiet     Be quiet.
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

error() {
    echo "$prog: $*" >&2
    exit 1
}

bad_option () {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

verbose() {
    local level=$1
    shift

    [ $verbose -lt $level ] || echo "$prog: $*" >&2
}

for alias in qpop qrefresh qfold ; do
    unalias $alias 2>/dev/null || true
done

qpop() {
    if $dry_run ; then
        $run hg qpop --quiet "$@"
    else
        verbose 1 hg qpop --quiet "$@"
        $run hg qpop --quiet "$@" | (
            grep -Ev '^(now at:|patch queue now empty)' || true
	)
    fi
}

qrefresh() {
    if $dry_run ; then
        $run hg qrefresh "$@"
    else
        verbose 1 hg qrefresh "$@"
        $run hg qrefresh "$@"
    fi
}

qfold() {
    if $dry_run ; then
        $run hg qfold "$@"
    else
        verbose 1 hg qfold "$@"
        $run hg qfold "$@"
    fi
}

### command line #######################################################

dry_run=false
verbose=0

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -n | --dry-run) dry_run=true ;;
        -v | --verbose) ((++verbose)) ;;
        -q | --quiet) ((--verbose)) ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] || bad_option "$1"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

aname=$(hg qprev)
bname=$(hg qtop)

qrefresh --message= # FIXME: this has no effect
qpop
qfold $bname
