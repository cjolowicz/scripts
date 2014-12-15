#!/bin/bash

set -e

prog=$(basename $0)

### usage ##############################################################

usage() {
    echo "\
usage: $prog [options] [patch]..
       $prog [options] --applied

options:
    -a, --applied    Replay all applied patches.
        --cwd DIR    Change working directory.
    -s, --sleep N    Sleep N seconds after each push.
    -r, --refresh    Refresh each patch.
    -p, --print      Print each patch.
    -h, --help       Display this message.
"
    exit
}

### command line #######################################################

error() {
    echo "$prog: error: $*" >&2
    exit 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

missing_arg () {
    bad_usage "option \`$1' requires an argument"
}

unknown_option () {
    bad_usage "unrecognized option \`$1'"
}

sleep=
cwd=
applied=false
print=false
refresh=false
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --cwd) [ $# -gt 0 ] || missing_arg "$option" ; cwd="$1" ; shift ;;
        -a | --applied) applied=true ;;
        -p | --print) print=true ;;
        -r | --refresh) refresh=true ;;
        -s | --sleep) [ $# -gt 0 ] || missing_arg "$option" ; sleep="$1" ; shift ;;
        -h | --help) usage ;;
        --) break ;;
        -*) unknown_option "$option" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

if [ -n "$cwd" ] ; then
    cd "$cwd"
fi

if ! $applied ; then
    [ $# -gt 0 ] || bad_usage "missing argument"
else
    [ $# -eq 0 ] || bad_usage "unexpected argument \`$1'"
    set -- $(hg qapplied)
fi

### main ###############################################################

hg root >/dev/null || error "no repository"
hg root --mq >/dev/null || error "no patch repository"

qtop="$(hg qtop)" 2>/dev/null

for patch ; do
    hg qgoto --quiet "$patch" || exit $?

    ! $print || hg tip
    ! $refresh || hg qrefresh

    [ -z "$sleep" ] || sleep $sleep
done

if [ -n "$qtop" ] ; then
    hg qgoto --quiet "$qtop"
else
    hg qpop --quiet --all
fi
