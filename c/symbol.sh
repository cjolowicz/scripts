#!/bin/bash

CC=${CC:-gcc}

tmpfile=/tmp/$(basename $0)_$RANDOM$RANDOM

trap 'rm -f $tmpfile $tmpfile.c' EXIT

verbose=0
string=0
while [ $# -gt 0 ]
do
    arg="$1"
    shift

    case $arg in
        --)            break;;
        -s|--string)   string=1;;
        -i|--int)      string=0;;
        -v|--verbose)  verbose=1;;
        -h|--header)
            [ $# -gt 0 ] || exit 2
            EXTRA_HEADERS="$EXTRA_HEADERS
#include <$1>"
            shift
            ;;
        -*) exit 2;;
        *) set -- "$arg" "$@"; break;;
    esac
done

symbol="$@"

cat <<EOF >$tmpfile.c
#include <stdlib.h>
#include <sys/types.h>
#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdio.h>
$EXTRA_HEADERS

int main()
{
#if $string
    printf("%s\n", (char*) $symbol);
#else
    printf("%lld\n", (long long int) $symbol);
#endif
    return 0;
}
EOF

if [ $verbose -ne 0 ]
then
    echo "==> $tmpfile.c <=="
    cat $tmpfile.c
    echo
    echo "==> output <=="
fi

$CC -o $tmpfile $tmpfile.c &&
$tmpfile
