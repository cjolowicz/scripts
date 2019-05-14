#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [commits]
Amend the specified commits.

options:
    -v, --verbose   Be verbose.
    -n, --dry-run   Print commands instead of executing them.
    -h, --help      Display this message.
"
}

bad_usage() {
    echo "$program: $*" >&2
    echo "Try \`$program --help' for more information." >&2
    exit 1
}

### command line #######################################################

options=()

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -v | --verbose)
            options+=(--verbose)
            ;;

        -n | --dry-run)
            options+=(--dry-run)
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

### main ###############################################################

[ $# -gt 0 ] || bad_usage "missing commit"

for commit
do
    options+=(--edit="$commit")
done

exec git-rebase-batch ${options+"${options[@]}"}
