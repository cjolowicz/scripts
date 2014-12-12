#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $prog [options]
Swap the two top-most patches { A B } to { B A }.

options:
    -n, --dry-run   Print commands instead of executing them.
    -h, --help      Display this message.
"
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

for alias in qpush qpop ; do
    unalias $alias 2>/dev/null || true
done

qpush() {
    if $dry_run ; then
        $run hg qpush --quiet "$@"
    else
        hg qpush --quiet "$@" 2>&1 | (
            grep -Ev '^(now at:|patch .* is empty)' || true
	) >&2
    fi
}

qpop() {
    if $dry_run ; then
        $run hg qpop --quiet "$@"
    else
        hg qpop --quiet "$@" | (
	    grep -v '^now at:' || true
	)
    fi
}

### command line #######################################################

dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -n | --dry-run) dry_run=true ;;
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

aname="$(hg qprev)" || error "both patches must be applied"
bname="$(hg qtop)"

qpop
qpop

qpush --move "$bname"
qpush
