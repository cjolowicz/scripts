#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options]
Upgrade dependencies using Poetry.

This is a front-end to \`poetry update\`.

By default, the script determines outdated dependencies using \`poetry show
--outdated\`, and performs the following actions for every reported package:

    1. Switch to a new branch \`upgrade/<package>-<version>\`.
    2. Update the dependency.
    3. Commit the changes to pyproject.toml and poetry.lock.
    4. Push to origin (optional).

options:
    --commit     Commit the changes to Git (default).
    --push       Push the changes to origin.
    --no-commit  Do not commit the changes to Git.
    --no-push    Do not push the changes to origin (default).
    -h, --help   Display this message.
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

### command line #######################################################

commit=true
push=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --commit)
            commit=true
            ;;

        --no-commit)
            commit=false
            ;;

        --push)
            push=true
            ;;

        --no-push)
            push=false
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

### main ###############################################################

branch=$(git rev-parse --abbrev-ref HEAD)

git diff --quiet --exit-code || error "Working tree is not clean"

poetry show --outdated --no-ansi |
    awk '{ print $1, $3 }' |
    while read package version
do
    echo "==> $package $version <=="
    echo

    branch=upgrade/$package-$version

    if $commit
    then
        git switch --create $branch master
    elif $push
    then
        git switch $branch
    fi

    poetry update $package

    if $commit
    then
        git add pyproject.toml poetry.lock
        git commit --message="Upgrade to $package $version"
    fi

    if $push
    then
        git push --set-upstream origin $branch
    fi

    echo
done

git switch $branch
