#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [upstream] [branch..]
Rebase multiple branches.

This tool does not yet handle resume. Use git rebase --continue, then invoke
this tool again with updated arguments.

options:
        --onto=<newbase>   New base (default: upstream)
    -v, --verbose          Be verbose.
    -n, --dry-run          Print commands instead of executing them.
    -h, --help             Display this message.
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

onto=
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --onto)
            [ $# -gt 0 ] || missing_arg "$option"
            onto="$1"
            shift
            ;;

        --onto=*)
            onto="${option#--onto=}"
            ;;

        -v | --verbose)
            verbose=true
            options+=(--verbose)
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

if [ $# -gt 0 ]
then
    upstream="$1"
    shift
fi

if [ -z "$onto" ]
then
    onto=$upstream
fi

if [ $# -eq 0 ]
then
    $git rebase --onto=$onto $upstream
else
    for branch
    do
        orig_branch=$(git rev-parse $branch)

        if [ -z "$onto" ]
        then
            $git rebase $upstream $branch
        else
            $git rebase --onto=$onto $upstream $branch
        fi

        upstream=$orig_branch
        onto=$branch
    done
fi
