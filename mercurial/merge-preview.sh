#!/bin/bash

prog=$(basename $0)

### functions ##########################################################

usage () {
    echo "usage: $prog [options] REV

options:
    -h, --help    Display this message.

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

options=()
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
            options+=("$option" "$1")
            shift
            break
            ;;

        -h | --help) usage ;;
        --) options+=("$option") ; break ;;
        -*) options+=("$option") ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -gt 0 ] || bad_usage "missing argument"

revision="$1" ; shift

[ $# -eq 0 ] || bad_usage "unknown argument \`$1'"

### main ###############################################################

echo $revision | grep -q '^[A-Za-z0-9]+$' ||
    revision="\"$revision\""

parents=($(hg parents --template '{node|short}\n')) ||
    error "cannot determine parents of the working directory"

[ ${#parents[@]} -eq 1 ] ||
    error "working directory must have a single parent"

parent=${parents[0]}

hg log "${options[@]}" -r "
    descendants(ancestor($parent, $revision)) and
    not ancestor($parent, $revision)          and
    (ancestors($revision) or $revision)
"
