#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "usage: $prog [options] [patches]
Append the patch number to the first line of each description.

options:
    -h, --help    Display this message.
"
}

### command line #######################################################

bad_option () {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

missing_arg () {
    echo "$prog: option \`$1' requires an argument" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

### main ###############################################################

i=0
n=$#

for patch
do
    ((++i))

    hg qgoto "$patch" || exit $?
    hg qrefresh -m"$(hg tip --template '{desc}' | sed -e "1a\\ ($i/$n)")"
done
