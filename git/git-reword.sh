#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [commits]
Edit the commit message of the specified commits, or HEAD.

options:
    -m, --message=TEXT  Change the commit message.
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

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

verbose_git() {
    echo git "$@"
    command git "$@"
}

### command line #######################################################

message=
options=()
dry_run=false
verbose=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -m | --message)
            [ $# -gt 0 ] || missing_arg "$option"
            message="$1"
            shift
            ;;

        --message=*)
            message="${option#--message=}"
            ;;

        -m*)
            message="${option:2}"
            ;;

        -v | --verbose)
            options+=(--verbose)
            verbose=true
            ;;

        -n | --dry-run)
            options+=(--dry-run)
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

[ $# -gt 0 ] || set -- HEAD

if [ -n "$message" ]
then
    for commit
    do
        git-rebase-batch ${options+"${options[@]}"} --edit="$commit"
        $git commit --amend --message="$message"
        $git rebase --continue
    done
else
    for commit
    do
        options+=(--reword="$commit")
    done

    exec git-rebase-batch ${options+"${options[@]}"}
fi
