#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [commit] [files]
Fixup the specified git commit.

options:
    -a, --all           Stage modified and deleted files.
    -p, --patch         Choose patches interactively.
    -s, --stash         Stash changes during rebase.
    -v, --verbose       Be verbose.
    -n, --dry-run       Print commands instead of executing them.
    -h, --help          Display this message.
"
}

error() {
    echo "$program: $*" >&2
    exit 1
}

bad_usage() {
    echo "$program: $*" >&2
    echo "Try \`$program --help' for more information." >&2
    exit 1
}

verbose_git() {
    echo git "$@"
    command git "$@"
}

### command line #######################################################

commit_options=()
stash=false
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -a | --all)
            commit_options+=(--all)
            ;;

        -p | --patch)
            commit_options+=(--patch)
            ;;

        -s | --stash)
            stash=true
            ;;

        -v | --verbose)
            verbose=true
            ;;

        -n | --dry-run)
            dry_run=true
            ;;

        -h | --help)
            usage
            exit
            ;;

        --)
            break
            ;;

        -?)
            bad_usage "unrecognized option \`$option'"
            ;;

        -*)
            set -- "${option::2}" -"${option:2}" "$@"
            ;;

        *)
            set -- "$option" "$@"
            break
            ;;
    esac
done

if [ $# -eq 0 ]
then
    commit=HEAD
elif [ ! -e "$1" ]
then
    commit="$1"
    shift
fi

if $dry_run
then
    git='echo git'
elif $verbose
then
    git=verbose_git
else
    git=git
fi

### main ###############################################################

commit=$(git rev-parse $commit)

$git commit ${commit_options[@]+"${commit_options[@]}"} --fixup=$commit "$@"

if $stash
then
    git stash
fi

GIT_EDITOR=true $git rebase --interactive $commit^

if $stash
then
    git stash pop
fi
