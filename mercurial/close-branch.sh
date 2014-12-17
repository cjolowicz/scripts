#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [branch]..
usage: $prog [options] --all

Close the specified branches.

Options:
    -a, --all       Close all inactive branches.
    -n, --dry-run   Print commands instead of executing them.
    -h, --help      Display this message.
"
}

info() {
    echo "$prog: $*" >&2
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

print_inactive_branches() {
    hg branches |
    grep '(inactive)$' |
    cut -d' ' -f1
}

close_branch() {
    local branch="$1"

    if $dry_run ; then
        $run hg update --quiet "\"$branch\""
    else
        $run hg update --quiet "$branch"
    fi

    if $dry_run ; then
        $run hg commit --message="\"Close $branch branch.\"" --close-branch
    else
        $run hg commit --message="Close $branch branch." --close-branch
    fi
}

### command line #######################################################

all=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -a | --all) all=true ;;
        -n | --dry-run) dry_run=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

if $all ; then
    set -- $(print_inactive_branches)
fi

[ $# -gt 0 ] || bad_usage "no branches specified"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

hgroot="$(hg root)" ||
    error "no repository"

active="$(hg branch)"

for branch ; do
    [ "$branch" != "$active" ] ||
        error "cannot close active branch \`$branch'"

    if ! $dry_run ; then
        info "$branch"
    fi

    close_branch "$branch"
done

if $dry_run ; then
    $run hg update --quiet "\"$active\""
else
    $run hg update --quiet "$active"
fi
