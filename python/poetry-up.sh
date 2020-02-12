#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options]
Upgrade dependencies using Poetry.

options:
    --push       Push the changes to origin.
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

push=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
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

[ -z "$(git status --porcelain)" ] || error "Working tree is not clean"

poetry show --outdated --no-ansi |
    awk '{ print $1, $3 }' |
    while read package version
do
    branch=upgrade/$package-$version

    git switch --create $branch master
    poetry update $package
    git add pyproject.toml poetry.lock
    git commit --message="Upgrade to $package $version"

    if $push
    then
        git push --set-upstream origin $branch
    fi
done

git switch $branch
