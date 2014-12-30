#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [branch]..

Open the specified branch.

Options:
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

open_branch() {
    local branch="$1"

    if $dry_run ; then
        $run hg branch --quiet "\"$branch\""
    else
        $run hg branch --quiet "$branch"
    fi

    if $dry_run ; then
        $run hg commit --message="\"Open $branch branch.\""
    else
        $run hg commit --message="Open $branch branch."
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

[ $# -gt 0 ] || bad_usage "no branch specified"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

parents=($(hg parents --template ' {node|short}'))

[ ${#parents[@]} -gt 0 ] || error "working directory has no parent"
[ ${#parents[@]} -eq 1 ] || error "working directory has multiple parents"

parent=${parents[0]}

for branch ; do
    if ! $dry_run ; then
        info "$branch"
    fi

    if [ "$parent" != "$(hg branch)" ] ; then
	if $dry_run ; then
	    $run hg update --quiet "\"$parent\""
	else
	    $run hg update --quiet "$parent"
	fi
    fi

    open_branch "$branch"
done
