#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage () {
    echo "$prog [options] command [arguments]
Pipe stderr to a filter.

options:

    -h, --help             display this message
    -c, --command FILTER   process standard error with this filter
        --pipefail         return the status of the last failed command
"
}

### parse command line #################################################

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

filter=
while [ $# -gt 0 ] ; do
    opt=$1
    shift

    case $opt in
        -c | --command) [ $# -ne 0 ] || missing_arg $opt ; filter="$1" ; shift ;;
        -h | --help) usage ; exit ;;
        --pipefail) set -o pipefail ;;
        --) break ;;
        -*) bad_option $opt ;;
        *) set -- "$opt" "$@" ; break ;;
    esac
done

### main ###############################################################

if [ -z "$filter" ] ; then
    "$@"
else
    exec 3>&1
    "$@" 2>&1 1>&3 | eval "$filter" 1>&2
fi
