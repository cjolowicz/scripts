#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $prog [options]
Fold the two top-most patches { A B } into B.

options:
    -n, --dry-run   Print commands instead of executing them.
    -v, --verbose   Be verbose.
    -q, --quiet     Be quiet.
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

error() {
    echo "$prog: $*" >&2
    exit 1
}

bad_option() {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

verbose() {
    local level=$1
    shift

    [ $verbose -lt $level ] || echo "$prog: $*" >&2
}

for alias in qpush qpop qgoto qrefresh qfold qnew ; do
    unalias $alias 2>/dev/null || true
done

qpush() {
    if $dry_run ; then
        $run hg qpush --quiet "$@"
    else
        verbose 2 hg qpush --quiet "$@"
        $run hg qpush --quiet "$@" 2>&1 | (
            grep -Ev '^(now at:|patch .* is empty)' || true
	) >&2
    fi
}

qpop() {
    if $dry_run ; then
        $run hg qpop --quiet "$@"
    else
        verbose 2 hg qpop --quiet "$@"
        $run hg qpop --quiet "$@" | (
            grep -Ev '^(now at:|patch queue now empty)' || true
	)
    fi
}

qgoto() {
    if $dry_run ; then
        $run hg qgoto --quiet "$@"
    else
        verbose 2 hg qgoto --quiet "$@"
        $run hg qgoto --quiet "$@" 2>&1 | (
            grep -Ev '^(now at:|patch .* is empty)' || true
	) >&2
    fi
}

qrefresh() {
    if $dry_run ; then
        $run hg qrefresh "$@"
    else
        verbose 2 hg qrefresh "$@"
        $run hg qrefresh "$@"
    fi
}

qfold() {
    if $dry_run ; then
        $run hg qfold "$@"
    else
        verbose 2 hg qfold "$@"
        $run hg qfold "$@"
    fi
}

qnew() {
    if $dry_run ; then
        $run hg qnew "$@"
    else
        verbose 2 hg qnew "$@"
        $run hg qnew "$@"
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

hgroot=$(hg root) ||
    error "no repository"

aname=$(hg qprev)
bname=$(hg qtop)
cname=TMP-$bname

qrefresh --exclude "$hgroot"
qnew $cname
qgoto $aname
qrefresh --message= # FIXME: this has no effect
qpop
qpush --move $bname
qfold $aname
qfold $cname
