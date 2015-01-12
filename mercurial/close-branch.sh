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
        --cwd DIR   Change working directory.
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

missing_arg() {
    bad_usage "option \`$1' requires an argument"
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

if [ -n "$cwd" ] ; then
    if $dry_run ; then
        $run cd "$cwd"
    fi

    cd "$cwd"
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
