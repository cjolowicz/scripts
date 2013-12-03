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

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
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
    merge-preview --template ' * {desc|firstline} [{node|short}]\n'
else
    echo "Merge $1 branch."
    echo
    merge-preview --template ' * [{branch}/{node|short}] {desc|firstline}\n' "$1" |
    sed "s,\\[$1/,[,"
fi
