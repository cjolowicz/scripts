#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options]
Non-interactive frontend to git rebase --interactive.

options:
    -r, --reword=<commit>  Edit the commit message.
    -e, --edit=<commit>    Stop for amending.
    -s, --squash=<commit>  Meld into previous commit.
    -f, --fixup=<commit>   Like \"squash\", but discard this commit's log message.
    -d, --drop=<commit>    Remove commit.
    -v, --verbose          Be verbose.
    -n, --dry-run          Print commands instead of executing them.
    -h, --help             Display this message.
"
}

# p, pick <commit> = use commit
# r, reword <commit> = use commit, but edit the commit message
# e, edit <commit> = use commit, but stop for amending
# s, squash <commit> = use commit, but meld into previous commit
# f, fixup <commit> = like "squash", but discard this commit's log message
# x, exec <command> = run command (the rest of the line) using shell
# b, break = stop here (continue rebase later with 'git rebase --continue')
# d, drop <commit> = remove commit
# l, label <label> = label current HEAD with a name
# t, reset <label> = reset HEAD to a label
# m, merge [-C <commit> | -c <commit>] <label> [# <oneline>]
# .       create a merge commit using the original merge commit's
# .       message (or the oneline, if no original merge commit was
# .       specified). Use -c <commit> to reword the commit message.

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

commands=()
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -d | --drop)
            [ $# -gt 0 ] || missing_arg "$option"
            commands+=(drop="$1")
            shift
            ;;

        --drop=*)
            commands+=(drop="${option#--drop=}")
            ;;

        -d*)
            commands+=(drop="${option:2}")
            ;;

        -e | --edit)
            [ $# -gt 0 ] || missing_arg "$option"
            commands+=(edit="$1")
            shift
            ;;

        --edit=*)
            commands+=(edit="${option#--edit=}")
            ;;

        -e*)
            commands+=(edit="${option:2}")
            ;;

        -r | --reword)
            [ $# -gt 0 ] || missing_arg "$option"
            commands+=(reword="$1")
            shift
            ;;

        --reword=*)
            commands+=(reword="${option#--reword=}")
            ;;

        -r*)
            commands+=(reword="${option:2}")
            ;;

        -s | --squash)
            [ $# -gt 0 ] || missing_arg "$option"
            commands+=(squash="$1")
            shift
            ;;

        --squash=*)
            commands+=(squash="${option#--squash=}")
            ;;

        -s*)
            commands+=(squash="${option:2}")
            ;;

        -f | --fixup)
            [ $# -gt 0 ] || missing_arg "$option"
            commands+=(fixup="$1")
            shift
            ;;

        --fixup=*)
            commands+=(fixup="${option#--fixup=}")
            ;;

        -f*)
            commands+=(fixup="${option:2}")
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

[ $# -eq 0 ] || bad_usage "unrecognized argument \`$1'"

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

for command in ${commands+"${commands[@]}"}
do
    commit="${command#*=}"
    command=${command%=*}

    commit=$(git rev-parse --short "$commit")

    export GIT_SEQUENCE_EDITOR="sed -i 's/^pick $commit /$command $commit /'"

    if $dry_run
    then
        echo "export GIT_SEQUENCE_EDITOR=\"$GIT_SEQUENCE_EDITOR\""
    fi

    $git rebase -i $commit^
done
