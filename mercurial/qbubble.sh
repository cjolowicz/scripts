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
    ! $verbose || echo "$prog: $*" >&2
}

for alias in qpush qpop qrefresh qnew qdelete qimport ; do
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

qrefresh() {
    $run hg qrefresh "$@"
}

qnew() {
    $run hg qnew "$@"
}

qdelete() {
    $run hg qdelete "$@"
}

qimport() {
    if $dry_run ; then
        $run hg qimport --quiet "$@"
    else
        hg qimport --quiet "$@" 2>&1 | (
            grep -Ev '^(adding .* to series file)' || true
        ) >&2
    fi
}

qfoldl() {
    if $dry_run ; then
        command qfoldl --dry-run "$@"
    else
        command qfoldl "$@"
    fi
}

qfoldr() {
    if $dry_run ; then
        command qfoldr --dry-run "$@"
    else
        command qfoldr "$@"
    fi
}

reverse() {
    if $dry_run ; then
        $run hg diff --git --reverse --change $1 \|
        qimport --quiet --git --name REVERSE-$1 -
    else
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

    verbose "preparing..."

    qpop                 # { A       | B }
    qrefresh --exclude . # { 0       | B } -- "0" is a zero patch with A's metainfo
    qnew $acopy          # { 0 A'    | B }
    qpop                 # { 0       | A' B }
    qpop                 # {         | 0 A' B }
    qpush --move $acopy  # { A'      | 0 B }
    qpush --move $b      # { A' B    | 0 }

    verbose "reverse \`$a'"

    reverse $acopy ||    # { A' B -A | 0 }
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
    verbose "cleaning up..."

    qpop            # { A' B | -A 0 }
    qpop            # { A'   | B -A 0 }
    qpop            # {      | A' B -A 0 }
    qpush --move $a # { 0    | A' B -A }
    qpush           # { 0 A' | B -A }
    qfoldl          # { A    | B -A }
    qpush           # { A B  | -A }
    qdelete $arev   # { A B }

    verbose "done."
}

finish() {
    verbose "reverse-reverse \`$a'"

    qpush            # { A' B -A 0 }
    reverse $arev || # { A' B -A 0 --A }
        error "cannot reverse $arev"

    qfoldl # { A' B -A A" }
    qpop   # { A' B -A | A" }

    verbose "fold into \`$b'"

    qfoldl # { A' B'   | A" }
    qfoldr # { B"      | A" }
    qpush  # { B" A" }

    verbose "done."
}

### command line #######################################################

continue=false
abort=false
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -c | --continue) continue=true ;;
        -A | --abort) abort=true ;;
        -n | --dry-run) dry_run=true ;;
        -v | --verbose) verbose=true ;;
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
