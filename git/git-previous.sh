#!/bin/bash
# Inspired by https://coderwall.com/p/ok-iyg/git-prev-next

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options]
Check out the previous commit.

options:
    -b <branch>         Create branch at the previous commit.
    -B <branch>         Create branch if it doesn't exist, otherwise reset it.
    -v, --verbose       Be verbose.
    -p, --print         Print the commit SHA-1 instead of checking it out.
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

checkout_options=()
verbose=false
print=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -b | -B)
            [ $# -gt 0 ] || missing_arg "$option"
            checkout_options+=($option "$1")
            shift
            ;;

        -v | --verbose)
            verbose=true
            ;;

        -p | --print)
            print=true
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

previous=$(git rev-parse HEAD^)

if ! git cat-file -e "${previous}^{commit}"
then
    error "cannot determine previous commit"
elif $print
then
    echo $previous
else
    $git checkout ${checkout_options+"${checkout_options[@]}"} $previous
fi
