#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "usage: $prog [options] sed-prog [patches]
Invoke sed on each patch description.

options:
    -h, --help    Display this message.
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
        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -gt 0 ] || bad_usage "missing argument"

sed="$1" ; shift

### main ###############################################################

for patch
do
    hg qgoto "$patch" ||
        error "cannot apply patch"

    desc="$(hg tip --template '{desc}')" ||
        error "cannot read patch description"

    desc="$(echo "$desc" | sed -e "$sed")" ||
        error "cannot transform patch description"

    hg qrefresh -m"$desc" ||
        error "cannot refresh patch"
done
