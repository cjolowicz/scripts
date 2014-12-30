#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options]
Restore queue to its checkout state.

This program functions as a front-end to \`hg revert --mq'. Patches
are popped before reverting the patch queue. The program attempts to
re-apply the previous patches after reverting.

options:
    -r, --rev REV   Revert to the specified queue revision.
    -C, --no-backup Do not save backup copies of patches.
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
options=()
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

        -r | --rev)
            [ $# -gt 0 ] || missing_arg "$option"
            options+=(--rev "$1")
            shift
            ;;

        -C | --no-backup)
            options+=(--no-backup)
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

oldtop="$(hg qtop | grep -v 'no patches applied')" 2>/dev/null || true

[ -z "$oldtop" ] || $run hg qpop --all

$run hg revert --mq --all "${options[@]}"

[ -z "$oldtop" ] || $run hg qgoto "$oldtop"
