#!/bin/bash

set -e

program=$(basename $0)
branch=$program-branch
tag=$program-commit

### functions ##########################################################

usage() {
    echo "usage: $program [options] [commit]
Amend the specified git commit.

options:
    -e, --edit          Edit the commit message.
    -m, --message TEXT  Change the commit message.
    -c, --continue      Resume operation after performing changes.
    -a, --abort         Abort operation.
    -C, --cwd DIR       Change working directory.
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

edit=false
message=
abort=false
continue=false
cwd=
dry_run=false
verbose=false
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -C | --cwd)
            [ $# -gt 0 ] || missing_arg "$option"
            cwd="$1"
            shift
            ;;

        -m | --message)
            [ $# -gt 0 ] || missing_arg "$option"
            message="$1"
            shift
            ;;

        -c | --continue)
            continue=true
            ;;

        -a | --abort)
            abort=true
            ;;

        -e | --edit)
            edit=true
            ;;

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

if ! $continue && ! $abort
then
    if [ $# -gt 0 ]
    then
        argument="$1"
        shift
    else
        argument=HEAD
    fi
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

if [ -n "$cwd" ] ; then
    cd "$cwd"
fi

branch_of() {
    local branches=($(
	git for-each-ref --contains $1 |
            while read ref type file
            do
		dirname=$(dirname "$file")
		if [ "$type" = commit -a "$dirname" = refs/heads ]
		then
		    basename "$file"
		fi
            done))

    if [ ${#branches[@]} -eq 1 ]
    then
        echo ${branches[0]}
    fi
}

setup() {
    status=$(git status --porcelain) && [ -z "$status" ] ||
        error "there are uncommitted changes in the working directory"

    if in_progress=$(git rev-parse --verify --quiet $branch) && [ -n "$in_progress" ]
    then
        error "already in progress, use --continue or --abort"
    fi

    commit=$(git rev-parse --verify --quiet "$argument") ||
        error "cannot parse commit \`$argument'"

    $git tag $tag $commit

    parent=$(git rev-parse --verify --quiet ${commit}~)

    if [ -n "$parent" ]
    then
        $git checkout --quiet -b $branch $parent
    else
        $git checkout --quiet --orphan $branch
    fi

    $git cherry-pick --quiet $commit
}

continue_() {
    if $dry_run
    then
        if [ -n "$commit" ]
        then
            branch_of=$(branch_of $commit)
            branch_of=${branch_of:-'<branch>'}
        else
            commit='<commit>'
            branch_of='<branch>'
        fi
    else
        commit=$(git rev-parse --quiet --verify $tag) ||
            error "cannot determine amended commit from tag $tag"
        branch_of=$(branch_of $commit)

        [ -n "$branch_of" ] ||
            error "cannot determine branch of commit $commit"
    fi

    $git rebase --quiet --onto $branch $commit $branch_of
    $git branch --quiet --delete $branch
    $git tag --delete $tag >/dev/null
}

abort() {
    $git cherry-pick --quiet --abort || true

    commit=$(git rev-parse --quiet --verify $tag) || true
    if [ -n "$commit" ]
    then
        branch_of=$(branch_of $commit)
        if [ -n $branch_of ]
        then
            $git checkout --quiet $(branch_of $commit) || true
        fi
    fi

    $git branch --quiet --delete $branch || true
    $git tag --delete $tag >/dev/null || true
}

if $abort
then
    abort
elif $continue ; then
    $git commit --amend -aC $tag
    continue_
elif [ -n "$message" ]
then
    setup
    $git commit --amend --message="$message"
    continue_
elif $edit
then
    setup
    $git commit --amend --edit
    continue_
else
    setup
    echo "Modify the commit, then invoke \`$program --continue'." >&2
fi
