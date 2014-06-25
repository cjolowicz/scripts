#!/bin/bash

set -e

prog=$(basename $0)

### defaults ###########################################################

metric=vsize
bytes=1024
human_readable=false

### usage ##############################################################

usage () {
    echo "usage: $prog [options] [pid]..
Print the virtual memory size of the process in bytes.

options:
    -m, --metric NAME       Display this metric (default: $metric).
    -b, --bytes NUM         Number of bytes per unit (default: $bytes).
    -s, --human-readable    Display human readable numbers.
    -h, --help              Display this message.
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
        -m | --metric) [ $# -gt 0 ] || missing_arg "$option" ; metric="$1" ; shift ;;
        -b | --bytes)  [ $# -gt 0 ] || missing_arg "$option" ; bytes="$1" ; shift ;;
        -s | --human-readable) human_readable=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

### functions ##########################################################

is_numerical () {
    if echo "$1" | grep -q '[^0-9]' ; then
        return 1
    fi

    return 0
}

print_size() {
    local value

    for value ; do
        is_numerical "$value" || return 1

        if [ $((value / 1024 / 1024 / 1024)) -gt 0 ] ; then
            printf '%sG\n' $(bc <<<"scale=2; $value / 1024 / 1024 / 1024")
        elif [ $((value / 1024 / 1024)) -gt 0 ] ; then
            printf '%sM\n' $(bc <<<"scale=2; $value / 1024 / 1024")
        elif [ $((value / 1024)) -gt 0 ] ; then
            printf '%sK\n' $(bc <<<"scale=2; $value / 1024")
        else
            printf '%s\n' $value
        fi
    done
}

### main ###############################################################

for pid
do
    size=$(ps --pid=$pid -o $metric --no-headers)

    if $human_readable ; then
        print_size $((bytes * size)) || status=$?
    else
        printf '%s\n' $((bytes * size))
    fi
done
