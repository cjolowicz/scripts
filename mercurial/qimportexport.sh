#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [patch]..
       $prog [options] [--all | --applied | --unapplied]
Copy patches to another repository.

options:
    -t, --target-directory DIR   Target repository.
    -a, --all                    Import all patches.
    -A, --applied                Import all applied patches.
        --unapplied              Import all unapplied patches.
    -P, --push                   Push the patches.
        --cwd DIR                Change working directory.
    -n, --dry-run                Print commands instead of executing them.
    -h, --help                   Display this message.
"
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

missing_argument() {
    bad_usage "option \`$1' requires an argument"
}

unexpected_argument() {
    bad_usage "unexpected argument \`$1'"
}

unrecognized_option() {
    bad_usage "unrecognized option \`$1'"
}

### command line #######################################################

import_options=()
export_options=()
all=false
applied=false
unapplied=false
dry_run=false
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --cwd)
            [ $# -gt 0 ] || missing_argument "$option"
            export_options+=(--cwd "$1")
            shift
            ;;

        -t | --target-directory)
            [ $# -gt 0 ] || missing_argument "$option"
            import_options+=(--cwd "$1")
            shift
            ;;

        -P | --push)
            import_options+=(--push)
            ;;

        -a | --all)
            all=true
            ;;

        -A | --applied)
            applied=true
            ;;

        --unapplied)
            unapplied=true
            ;;

        -n | --dry-run)
            dry_run=true
            ;;

        -h | --help)
            usage
            ;;

        --)
            break
            ;;

        -*)
            unrecognized_option "$option"
            ;;

        *)
            set -- "$option" "$@"
            break
            ;;
    esac
done

if $dry_run ; then
    run=echo
fi

if $all ; then
    [ $# -eq 0 ] || unexpected_argument "$1"

    set -- $(hg qseries "${export_options[@]}")
elif $applied ; then
    [ $# -eq 0 ] || unexpected_argument "$1"

    set -- $(hg qapplied "${export_options[@]}")
elif $unapplied ; then
    [ $# -eq 0 ] || unexpected_argument "$1"

    set -- $(hg qunapplied "${export_options[@]}")
else
    [ $# -gt 0 ] || set -- $(hg qtop "${export_options[@]}")
fi

[ $# -gt 0 ] || bad_usage "no patch specified"

### main ###############################################################

mqroot="$(hg root "${export_options[@]}" --mq)"

( cd "$mqroot" && realpath "$@" ) |
xargs $run hg qimport "${import_options[@]}"
