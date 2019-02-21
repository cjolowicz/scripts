#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [commit] [files]
Fixup the specified git commit.

options:
    -#, --last=#        Fix up the (#th) last commit to modify each file
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

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

verbose_git() {
    echo git "$@"
    command git "$@"
}

### command line #######################################################

commit_options=()
last=
all=false
stash=false
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -[0-9])
            last=${option:1}
            ;;

        --last)
            [ $# -gt 0 ] || missing_arg "$option"
            last="$1"
            shift
            ;;

        --last=*)
            last="${option#--last=}"
            ;;

        -a | --all)
            all=true
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

if [ -n "$last" ]
then
    if ! [ "$last" -eq "$last" ]
    then
        bad_usage "--last=$last must be a number"
    fi
else
    if [ $# -gt 0 ] && [ ! -e "$1" ]
    then
        commit="$1"
        shift
    else
        commit=HEAD
    fi

    if $all
    then
        commit_options+=(--all)
    fi
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

if [ -n "$last" ]
then
    if [ $# -eq 0 ] && $all
    then
        set -- $(git diff --name-only)
    fi

    if [ $# -eq 0 ]
    then
        exit
    fi

    commits=()

    for file
    do
        commit=$(git rev-list -$last HEAD "$file" | tail -n1)

        $git commit ${commit_options[@]+"${commit_options[@]}"} --fixup=$commit "$file"

        commits+=($commit)
    done

    oldest=$(
        git rev-list --reverse --topo-order ${commits[@]} |
            grep ${commits[@]/#/-e } --max-count=1)

    if $stash
    then
        $git stash
    fi

    GIT_EDITOR=true $git rebase --interactive $oldest^

    if $stash
    then
        $git stash stop
    fi

    exit
fi

if ! $stash && ! $all
then
    status=$(git status --porcelain) && [ -z "$status" ] ||
        error "there are uncommitted changes in the working directory"
fi

commit=$(git rev-parse "$commit")

$git commit ${commit_options[@]+"${commit_options[@]}"} --fixup=$commit "$@"

if $stash
then
    $git stash
fi

GIT_EDITOR=true $git rebase --interactive $commit^

if $stash
then
    $git stash pop
fi
