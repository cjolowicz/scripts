#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [OLD] NEW

Rename the specified branch. With a single argument, rename the active
branch.

Options:
        --cwd DIR   Change working directory.
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

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

show_tip() {
    ! $verbose || hg tip
}

rename_branch() {
    local oldbranch="$1"
    local newbranch="$2"

    if [ $# -eq 1 ] ; then
        newbranch="$oldbranch"
        oldbranch="$(hg branch)"
    elif $dry_run ; then
        $run hg update --quiet "\"$oldbranch\""
    else
        $run hg update --quiet "$oldbranch"
    fi

    if $dry_run ; then
        $run hg commit --message="\"Close $oldbranch branch.\"" --close-branch
        $run hg branch --quiet "\"$newbranch\""
        $run hg commit --message="\"Open $newbranch branch.\""
    else
        $run hg commit --message="Close $oldbranch branch." --close-branch ; show_tip
        $run hg branch --quiet "$newbranch"
        $run hg commit --message="Open $newbranch branch." ; show_tip
    fi
}

### command line #######################################################

cwd=
dry_run=false
verbose=false

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
        -v | --verbose) verbose=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -gt 0 ] || bad_usage "no branch specified"

if $dry_run ; then
    run=echo
fi

if [ -n "$cwd" ] ; then
    if $dry_run ; then
        $run cd "$cwd"
    fi

    cd "$cwd"
fi

### main ###############################################################

hgroot="$(hg root)" || error "no repository"

rename_branch "$@"
