#!/bin/bash

prog=$(basename $0)

### functions ##########################################################

usage () {
    echo "usage: $prog [options] [REV]

options:
    -h, --help    Display this message.

Print the commit message for \`hg merge REV'.
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

hg_options=()

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -R | --repository    | \
             --cwd           | \
             --config        | \
             --encoding      | \
             --encodingmode  | \
             --color         | \
             --pager)
            [ $# -gt 0 ] || bad_usage "option \`$option' requires an argument"
            hg_options+=("$option" "$1")
            shift
            ;;

        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -le 1 ] || bad_usage "unknown argument \`$2'"

### main ###############################################################

if [ $# -eq 0 ] ; then
    echo "Merge."
    echo
    merge-preview "${hg_options[@]}" --template ' * {desc|firstline} [{node|short}]\n'
else
    echo "Merge $1 branch."
    echo
    merge-preview "${hg_options[@]}" --template ' * [{branch}/{node|short}] {desc|firstline}\n' "$1" |
    sed "s,\\[$1/,[,"
fi
