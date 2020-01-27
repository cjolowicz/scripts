#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] <version>
Bump version using Poetry.

This is a front-end to \`poetry version\`. By default, it performs the
following actions:

    1. Bump the version using Poetry.
    2. Modify \`__version__\` in the package.
    3. Commit the changes.
    4. Add a version tag.

options:
    --commit     Commit the changes to Git (default).
    --tag        Add a version tag (default).
    --push       Push the changes to origin.
    --no-commit  Do not commit the changes to Git.
    --no-tag     Do not add a version tag.
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

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

verbose_run() {
    echo "$@"
    "$@"
}

### command line #######################################################

commit=true
tag=true
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

        --tag)
            tag=true
            ;;

        --no-tag)
            tag=false
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

[ $# -gt 0 ] || bad_usage "missing argument <version>"

version=$1
shift

[ $# -eq 0 ] || bad_usage "unrecognized argument \`$1'"

### main ###############################################################

read name old_version <<< "$(poetry version)"

poetry version "$version"

read name new_version <<< "$(poetry version)"

sed_program='s/^\( *__version__ *= *\)"'"$old_version"'"/\1"'"$new_version"'"/'

find . -name '*.py' -print0 | xargs -0 sed -i "$sed_program"

message="$name $new_version"

if $commit
then
    git commit --all --message="$message"
fi

if $tag
then
    git tag --message="$message" "v$new_version"
fi

if $push
then
    git push --follow-tags
fi
