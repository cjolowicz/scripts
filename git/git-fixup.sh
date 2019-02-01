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
dry_run=false
verbose=false

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

if [ $# -gt 0 ]
then
    argument="$1"
    shift
else
    argument=HEAD
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

commit=$(git rev-parse $argument)

$git commit ${commit_options[@]+"${commit_options[@]}"} --fixup=$commit "$@"

GIT_EDITOR=true $git rebase --interactive $commit^
