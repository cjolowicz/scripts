#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options]
Restore queue to the previous saved state.

options:
        --cwd DIR   Change working directory.
    -n, --dry-run   Print commands instead of executing them.
    -h, --help      Display this message."
    exit
}

error() {
    echo "$prog: error: $*" >&2
    exit 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

### command line #######################################################

cwd=
dry_run=false
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --cwd)
            [ $# -gt 0 ] || missing_arg "$option"
            cwd="$1"
            shift
            ;;

        -n | --dry-run) dry_run=true ;;
        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

if $dry_run ; then
    run=echo
fi

### main ###############################################################

if [ -n "$cwd" ] ; then
    if $dry_run ; then
        $run cd "$cwd"
    fi

    cd "$cwd"
fi

hg root >/dev/null || error "no repository"
hg root --mq >/dev/null || error "no patch repository"

oldtop="$(hg qtop)" 2>/dev/null

$run hg qpop --all
$run hg update --clean --mq
$run hg purge --mq

[ -z "$oldtop" ] || $run hg qgoto "$oldtop"
