#!/bin/bash

set -eou pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] commit
Revert to the specified commit.

options:
        --no-edit       Do not start the commit message editor.
        --no-commit     Do not create a commit.
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

edit=true
commit=true
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --no-edit)
            edit=false
            ;;

        --no-commit)
            commit=false
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

[ $# -gt 0 ] || error "missing argument"

target=$1
shift

[ $# -eq 0 ] || error "unrecognized argument \`$1'"

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

head=$(git rev-parse HEAD)
target=$(git rev-parse $target)
summary="$(git show -s --format=%s $target)"
message="Revert to \"$summary\"

This commit reverts to $target."

status=$(git status --porcelain) && [ -z "$status" ] ||
    error "there are uncommitted changes in the working directory"

$git reset --hard $target
$git reset --mixed $head

if $commit
then
    commit_options=(--message="$message")

    if $edit
    then
        commit_options+=(--edit)
    fi

    $git add .
    $git commit "${commit_options[@]}"
fi
