#!/bin/bash

set -e
set -o pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [<options>] [--] [<commit>]

Replace commits ( P ; Q ) by ( P + Q ; -Q ).

In effect, this operation reverses the tree sequence ( T1 ; T2 ),
where T1 is the result of applying P to the parent and T2 is the
result of applying Q to T1.

options:
    -v, --verbose     Be verbose.
    -n, --dry-run     Print commands instead of executing them.
    -h, --help        Display this message.
"
}

##
# Note that this operation is its own inverse, since
#
#   REVERSE( REVERSE( P ; Q ) )
#   = REVERSE( P + Q ; -Q )
#   = ( P + Q + -Q ; --Q )
#   = ( P ; Q )
##

error() {
    echo "$program: $*" >&2
    exit 1
}

bad_usage() {
    echo "$program: $*" >&2
    echo "Try \`$program --help' for more information." >&2
    exit 1
}

function verbose_git() {
    echo git "$@"
    command git "$@"
}

uuidgen() {
    if [ -x /usr/bin/uuidgen ]
    then
        /usr/bin/uuidgen | tr 'A-Z' 'a-z'
    elif [ -e /dev/urandom ]
    then
        od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
    elif [ -e /dev/random ]
    then
        od -x /dev/random | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
    else
        error "cannot generate UUID for temporary branch"
    fi
}

### command line #######################################################

dry_run=false
verbose=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -n | --dry-run)
            dry_run=true
            ;;

        -v | --verbose)
            verbose=true
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
    commit=$1
    shift
else
    commit=HEAD
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

status=$(git status --porcelain) && [ -z "$status" ] ||
    error "there are uncommitted changes in the working directory"

head=$(git rev-parse $commit) ||
    error "cannot parse commit \`$commit'"

parent=$(git rev-parse ${commit}~) ||
    error "cannot parse commit \`${commit}~', does the given commit have a parent?"

root=$(git rev-list --max-parents=0 $commit) ||
    error "cannot determine root commit for \`$commit'"

branch=$(git symbolic-ref --short HEAD) ||
    error "cannot determine current branch"

git merge-base --is-ancestor $commit HEAD ||
    error "commit $commit is not on the current branch"

[ $(git branch --contains $commit | wc -l) -eq 1 ] ||
    error "commit $commit is on multiple branches"

# open temporary branch; squash parent and head
temp=$(uuidgen)

if [ $parent = $root ]
then
    $git checkout --quiet --orphan $temp
else
    $git checkout --quiet -b $temp ${commit}~2
    $git cherry-pick --quiet --no-commit $parent $head
fi

$git commit --quiet --all --reuse-message $parent

# reverse head
$git revert --no-commit $head
$git commit --quiet --all --reuse-message $head

# incorporate into branch
$git rebase --quiet --onto $temp $head $branch

# remove temporary branch
$git branch --quiet --delete $temp
