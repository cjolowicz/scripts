#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] <version>
Bump version using Poetry.

This is a front-end to \`poetry version\`. It uses Poetry to bump the version,
then modifies \`__version__\` in the installed package.

options:
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

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
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

get_version() {
    sed -n 's/^ *version *= *"\([^"]*\)"/\1/p' pyproject.toml
}

old_version=$(get_version)

poetry version "$version"

new_version=$(get_version)

sed_program='s/^\( *__version__ *= *\)"'"$old_version"'"/\1"'"$new_version"'"/'

find . -name '*.py' -print0 | xargs -0 sed -i "$sed_program"
