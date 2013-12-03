#!/bin/bash

prog=$(basename $0)

### functions ##########################################################

usage () {
    echo "usage: $prog [options]

options:
    -r, --rev REV     Specify the revision of .hgsubstate.
    -h, --help        Display this message.

Print the revisions of the subrepositories referenced in .hgsubstate.
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

header () {
    local begin= end=

    if [ -t 1 ] ; then
        begin="$(tput setf 2)"
        end="$(tput setf 7)"
    fi

    echo "${begin}==> $* <==${end}"
    echo
}

### command line #######################################################

options=()
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -r | --rev)
            [ $# -gt 0 ] || bad_usage "option \`$option' requires an argument"
            rev="$1"
            shift
            ;;

        -d | --date          | \
        -k | --keyword       | \
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
            options+=("$option" "$1")
            shift
            ;;

        -h | --help) usage ;;
        --) options+=("$option") ; break ;;
        -*) options+=("$option") ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] || bad_usage "unknown argument \`$1'"

### main ###############################################################

set -o pipefail

root="$(hg root)" || exit $?

if [ -z "$rev" ] ; then
    cat "$root"/.hgsubstate || exit $?
else
    hg --cwd "$root" cat -r "$rev" .hgsubstate || exit $?
fi |
while read changeset repository ; do
    header "$repository"

    hg --cwd "$root/$repository" log "${options[@]}" -r "$changeset"
done
