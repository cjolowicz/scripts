#!/bin/bash
# Inspired by https://coderwall.com/p/ok-iyg/git-prev-next

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [branch]
Check out the next commit on the current, or specified, branch.

options:
    -b <branch>         Create branch at the next commit.
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

if [ $# -eq 0 ]
then
    branch=
elif [ ! -e "$1" ]
then
    branch="$1"
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

if [ -z "$branch" ]
then
    branch=$(git rev-parse --abbrev-ref HEAD)
fi

head=$(git rev-parse HEAD)
next=$(git log --reverse --pretty=%H $branch | awk "/$head/{getline;print}")

if [ "$head" == "$next" ] || ! git cat-file -e "${next}^{commit}"
then
    error "cannot determine next commit"
elif $print
then
    echo $next
else
    $git checkout ${checkout_options+"${checkout_options[@]}"} $next
fi
