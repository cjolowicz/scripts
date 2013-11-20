#!/bin/bash

prog="$(basename $0)"

usage () {
    echo "usage: $prog [option].. [--] [revision]..

options:
    -h, --help     Display this message.
"
}

### parse command line #################################################

bad_option () {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

while [ $# -gt 0 ]
do
    opt="$1"
    shift

    case $opt in
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $opt ;;
        *) set -- "$opt" "$@" ; break ;;
    esac
done

if [ $# -eq 0 ] ; then
    usage
    exit
fi

### main ###############################################################

patchdir="$(hg root --mq)"

mkdir -p "$patchdir"

for revision ; do
    hg log --rev=$revision --template='{node|short}  {desc|firstline}' |
    cut -c-$(tput cols)

    patchname=$(hg log --rev=$revision --template='backport-{node|short}')

    if [ -z "$patchname" ] ; then
        echo "$prog: revision $revision not found" >&2
        exit 1
    fi

    hg log --rev $revision \
           --patch --git \
           --template 'Backport {node|short}: {desc}\n\n' \
        > "$patchdir"/$patchname

    stderr="$(hg qimport --existing $patchname --push 2>&1 >/dev/null)"
    status=$?

    if [ $status -ne 0 ] ; then
        echo "$stderr" >&2
        exit $status
    fi
done
