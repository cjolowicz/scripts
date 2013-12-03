#!/bin/bash

prog=$(basename $0)

### functions ##########################################################

usage () {
    echo "usage: $prog [options] [REV]

options:
    -h, --help    Display this message.

Print the revisions which would be merged by \`hg merge REV'.
All options accepted by \`hg log' are also accepted by this script.
"
    exit
}

error () {
    echo "$prog: error: $*" >&2
    exit 1
}

bad_usage () {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

### command line #######################################################

log_options=()
merge_options=(-P)
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -d | --date          | \
        -k | --keyword       | \
        -r | --rev           | \
        -u | --user          | \
        -b | --branch        | \
        -P | --prune         | \
        -l | --limit         | \
             --style         | \
             --template      | \
        -I | --include       | \
        -X | --exclude       | \
        -R | --repository    | \
             --cwd           | \
             --config        | \
             --encoding      | \
             --encodingmode  | \
             --color         | \
             --pager)
            [ $# -gt 0 ] || bad_usage "option \`$option' requires an argument"
            log_options+=("$option" "$1")
            shift
            ;;

        -h | --help) usage ;;
        --) log_options+=("$option") ; break ;;
        -*) log_options+=("$option") ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

if [ $# -gt 0 ] ; then
    merge_options+=("$1")
    shift
fi

[ $# -eq 0 ] || bad_usage "unknown argument \`$1'"

### main ###############################################################

set -o pipefail

revisions=($(hg merge "${merge_options[@]}" |
             sed -n 's/^changeset:.*:/-r /p')) ||
    error "cannot determine changesets to be merged"

[ ${#revisions[@]} -eq 0 ] ||
    hg log "${log_options[@]}" "${revisions[@]}"
