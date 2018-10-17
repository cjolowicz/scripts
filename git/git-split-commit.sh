#!/bin/bash

set -e
set -o pipefail

program=$(basename $0)
temp=$program-branch

### functions ##########################################################

usage() {
    echo "usage: $program [<options>] [--] [<commit>]

Untested! This script is supposed to be a non-interactive way to split
commits, similar to git rebase -i. It depends on another script called
git-reverse-tree.

options:
    -c, --continue    Resume operation after performing changes.
    -a, --abort       Abort operation.
    -v, --verbose     Be verbose.
    -n, --dry-run     Print commands instead of executing them.
    -h, --help        Display this message.
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

branch_of() {
    branches=($(git branch --contains $1))

    [ ${#branches[@]} -ne 0 ] ||
	error "commit $1 is not on any branch"

    [ ${#branches[@]} -eq 1 ] ||
	error "commit $1 is on multiple branches"

    echo ${branches[0]}
}

setup() {
    status=$(git status --porcelain) && [ -z "$status" ] ||
	error "there are uncommitted changes in the working directory"

    in_progress=$(git rev-parse --verify --quiet $temp)
    [ -z "$in_progress" ] ||
	error "already in progress, use --continue or --abort"

    commit=$(git rev-parse --verify $argument) ||
	error "cannot parse commit \`$argument'"

    git merge-base --is-ancestor $commit HEAD ||
	error "commit $commit is not on the current branch"

    branch=$(branch_of $commit)

    git tag $program-commit $commit

    parent=$(git rev-parse --verify --quiet ${commit}~)

    if [ -z "$parent" ]
    then
	$git checkout --quiet --orphan $temp
    else
	$git checkout --quiet -b $temp $parent
    fi

    $git cherry-pick --quiet $commit
}

continue_() {
    commit=$(git rev-parse --quiet --verify $program-commit) ||
	error "cannot verify tag $program-commit"

    branch=$(branch_of $commit)

    $git commit --quiet

    git-reverse-tree "${options[@]}"

    $git rebase --quiet --onto $temp $commit $branch
    $git branch --quiet --delete $temp
}

cleanup() {
    commit=$(git rev-parse --quiet --verify $program-commit)

    git tag --delete $program-commit

    if [ -n "$commit" ]
    then
	branch=$(branch_of $commit)
	$git checkout $branch
    fi

    $git branch --quiet --delete $temp
}

### command line #######################################################

options=()
continue=false
dry_run=false
verbose=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -c | --continue)
	    continue=true
	    ;;

        -n | --dry-run)
            dry_run=true
	    options+=(--dry-run)
            ;;

        -v | --verbose)
            verbose=true
	    options+=(--verbose)
            ;;

        -h | --help)
            usage
            exit
            ;;

        --)
            break
            ;;

        -*)
            bad_usage "unrecognized option \`$option'"
            ;;

        *)
            set -- "$option" "$@"
            break
            ;;
    esac
done

if [ $# -gt 0 ]
then
    argument=$1
    shift
else
    argument=HEAD
fi

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

temp=temp-$program

if $abort
then
    cleanup
elif $continue
then
    trap cleanup EXIT
    continue_
else
    setup
    echo "Modify the commit, then invoke \`$program --continue'." >&2
fi
