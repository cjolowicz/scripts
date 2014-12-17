#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $prog [options] [branch]
Merge the specified branch.

options:
    -c, --continue  Resume after conflict resolution.
    -A, --abort     Abort the operation.
    -n, --dry-run   Print commands instead of executing them.
    -v, --verbose   Be verbose.
    -h, --help      Display this message.
"
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

logfile() {
    echo "$tmpdir/$prog-$local-$other.tmp"
}

start() {
    local=$(hg parent --template '{node|short}')
    other=$(hg log --rev "$branch" --template '{node|short}')

    $run merge-message --output "$(logfile)" "$branch"
    $run hg merge "$branch" ||
        error "resolve conflicts, \`$prog --continue' to resume."
}

resume() {
    local=$(hg parent --template '{node|short}\n' | sed -n 1p)
    other=$(hg parent --template '{node|short}\n' | sed -n 2p)

    [ -n "$other" ] ||
        error "working directory does not have two parents"

    local rev=$(hg log --rev "$branch" --template '{node|short}')

    [ "$other" = "$rev" ] ||
        error "unexpected revision for $branch: $other"
}

finish() {
    $run hg commit --logfile "$(logfile)"
    $run rm -f "$(logfile)"
    $run hg tip --verbose
}

abort() {
    $run hg update --clean
    $run rm -f "$(logfile)"
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

[ $# -gt 0 ] || bad_usage "no branch specified"

branch="$1"
shift

[ $# -eq 0 ] || bad_option "$1"

! $abort || ! $continue ||
    bad_usage "specified both --abort and --continue"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

which merge-message >/dev/null 2>&1 ||
    error "merge-message not found"

tmpdir="${TMPDIR:-/tmp}"

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
