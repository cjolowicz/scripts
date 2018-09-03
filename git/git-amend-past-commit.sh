#!/bin/bash

set -e

program=$(basename $0)
branch=temp-amending
resume=false

### functions ##########################################################

usage() {
    echo "usage: $program [options] [commit]
Amend the specified git commit.

options:
    -e, --edit      Edit the commit message.
    -c, --continue  Resume operation after performing changes.
    -C, --cwd DIR   Change working directory.
    -h, --help      Display this message.
"
}

error() {
    echo "$prog: $*" >&2
    exit 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

bad_option() {
    bad_usage "unrecognized option \`$1'"
}

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

### command line #######################################################

edit=false
resume=false
cwd=
commit=

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

        -c | --continue) resume=true ;;
        -e | --edit) edit=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -gt 0 ] || bad_usage "no commit specified"

commit="$1"
shift

[ $# -eq 0 ] || bad_option "$1"

### main ###############################################################

if [ -n "$cwd" ] ; then
    cd "$cwd"
fi

setup() {
    git checkout -b $branch ${commit}~1
    git cherry-pick $commit
}

resume() {
    git rebase --onto $branch $commit master
    git branch --delete $branch
}

if $edit ; then
    setup
    git commit --amend --edit
    resume
elif $resume ; then
    git commit --amend -aC $commit
    resume
else
    setup
    echo "Modify the commit, then invoke \`$program --continue $commit'." >&2
fi
