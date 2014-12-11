#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "usage: $prog [options]

options:
        --cwd DIR   Change working directory.
    -f, --force     Overwrite existing message.
    -h, --help      Display this message.
"
    exit
}

error () {
    echo "$prog: error: $*" >&2
    exit 1
}

missing_arg () {
    bad_usage "option \`$1' requires an argument"
}

bad_usage () {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

### command line #######################################################

cwd=
force=false
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --cwd) [ $# -gt 0 ] || missing_arg "$option" ; cwd="$1" ; shift ;;
        -f | --force) force=true ;;
        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] ||
    bad_usage "unknown argument \`$1'"

if [ -n "$cwd" ] ; then
    cd "$cwd"
fi

### main ###############################################################

qtop="$(hg qtop)" ||
    error "no patch applied"

desc="$(hg tip --template '{desc}')" ||
    error "cannot read current description"

if [ -n "$desc" ] && [ "$desc" != "imported patch $qtop" ] && ! $force ; then
    error "description is already to set, use --force to override"
fi

desc="$(sed 's,.,\U&,;s,$,.,;s,-, ,g' <<< "$qtop")"

hg qrefresh --message "$desc"
