#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $prog [options]
Reverse the order of the two top-most patches.

options:
    -c, --continue  Resume after conflict resolution.
    -A, --abort     Abort the operation.
    -n, --dry-run   Print commands instead of executing them.
    -v, --verbose   Be verbose.
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

error() {
    echo "$prog: $*" >&2
    exit 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

bad_option() {
    bad_usage "unrecognized option \`$1'"
}

verbose() {
    local level=$1
    shift

    [ $verbose -lt $level ] || echo "$prog: $*" >&2
}

for alias in qpush qpop qrefresh qnew qdelete qimport ; do
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

qrefresh() {
    if $dry_run ; then
        $run hg qrefresh "$@"
    else
        verbose 2 hg qrefresh "$@"
        $run hg qrefresh "$@"
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

qdelete() {
    if $dry_run ; then
        $run hg qdelete "$@"
    else
        verbose 2 hg qdelete "$@"
        $run hg qdelete "$@"
    fi
}

qimport() {
    if $dry_run ; then
        $run hg qimport --quiet "$@"
    else
        verbose 2 hg qimport --quiet "$@"
        $run hg qimport --quiet "$@" 2>&1 | (
            grep -Ev '^(adding .* to series file)' || true
        ) >&2
    fi
}

qfoldl() {
    command qfoldl "${options[@]}" "$@"
}

qfoldr() {
    command qfoldr "${options[@]}" "$@"
}

reverse() {
    if $dry_run ; then
        $run hg diff --git --reverse --change $1 \|
        qimport --quiet --git --name REVERSE-$1 -
    else
        verbose 2 hg diff --git --reverse --change $1 \|
        hg diff --git --reverse --change $1 |
        qimport --quiet --git --name REVERSE-$1 -
    fi
    qpush
}

start() {
    a=$(hg qprev)
    b=$(hg qtop)
    acopy=COPY-$a
    arev=REVERSE-$acopy

    verbose 1 "preparing..."

    qpop                         # { A       | B }
    qrefresh --exclude "$hgroot" # { 0       | B } -- "0" is a zero patch with A's metainfo
    qnew $acopy                  # { 0 A'    | B }
    qpop                         # { 0       | A' B }
    qpop                         # {         | 0 A' B }
    qpush --move $acopy          # { A'      | 0 B }
    qpush --move $b              # { A' B    | 0 }

    verbose 1 "reverse \`$a'"

    reverse $acopy ||            # { A' B -A | 0 }
        error "resolve conflicts and qrefresh, \`$prog --continue' to resume."
}

resume() {
    a=$(hg qnext)
    b=$(hg qprev)
    acopy=$(hg qapplied | tail -n3 | head -n1)
    arev=$(hg qtop)

    [ "$acopy" = COPY-$a        ] || error "unexpected patch \"$acopy\", expected COPY-$a"
    [ "$arev"  = REVERSE-$acopy ] || error "unexpected patch \"$arev\", expected REVERSE-$acopy"
}

abort() {
    verbose 1 "cleaning up..."

    qpop            # { A' B | -A 0 }
    qpop            # { A'   | B -A 0 }
    qpop            # {      | A' B -A 0 }
    qpush --move $a # { 0    | A' B -A }
    qpush           # { 0 A' | B -A }
    qfoldl          # { A    | B -A }
    qpush           # { A B  | -A }
    qdelete $arev   # { A B }

    verbose 1 "done."
}

finish() {
    verbose 1 "reverse-reverse \`$a'"

    qpush            # { A' B -A 0 }
    reverse $arev || # { A' B -A 0 --A }
        error "cannot reverse $arev"

    qfoldl # { A' B -A A" }
    qpop   # { A' B -A | A" }

    verbose 1 "fold into \`$b'"

    qfoldl # { A' B'   | A" }
    qfoldr # { B"      | A" }
    qpush  # { B" A" }

    verbose 1 "done."
}

### command line #######################################################

options=()
continue=false
abort=false
verbose=0
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -c | --continue) continue=true ;;
        -A | --abort) abort=true ;;
        -n | --dry-run) dry_run=true ; options+=(--dry-run) ;;
        -v | --verbose) ((++verbose)) ; options+=(--verbose) ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] || bad_option "$1"

! $abort || ! $continue ||
    bad_usage "specified both --abort and --continue"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

hgroot=$(hg root) ||
    error "no repository"

which qfoldl >/dev/null 2>&1 ||
    error "qfoldl not found"

which qfoldr >/dev/null 2>&1 ||
    error "qfoldr not found"

if $abort ; then
    resume
    abort
elif $continue ; then
    resume
    finish
else
    start
    finish
fi
