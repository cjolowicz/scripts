#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "usage: $prog [options]

options:
    -p, --prepend TEXT    Prepend text to the description.
    -a, --append TEXT     Append text to the description.
    -h, --help            Display this message.
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

append=()
prepend=()
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -p | --prepend)
            [ $# -gt 0 ] || bad_usage "option \`$option' requires an argument"
            prepend+=("$1")
            shift
            ;;

        -a | --append)
            [ $# -gt 0 ] || bad_usage "option \`$option' requires an argument"
            append+=("$1")
            shift
            ;;

        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] ||
    bad_usage "unknown argument \`$1'"

[ "${#prepend[@]}" -gt 0 -o "${#append[@]}" -gt 0 ] ||
    bad_usage "option \`--prepend' or \`--append' is required"

### main ###############################################################

desc="$(hg tip --template '{desc}')" ||
    error "cannot read current description"

if [ "${#prepend[@]}" -gt 0 ] ; then
    for line in "${prepend[@]}" ; do
        desc="$line

$desc"
    done
fi

if [ "${#append[@]}" -gt 0 ] ; then
    for line in "${append[@]}" ; do
        desc="$desc

$line"
    done
fi

hg qrefresh -m "$desc"
