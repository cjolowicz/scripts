#!/bin/bash

CC=${CC:-gcc}

tmpfile=/tmp/$(basename $0)_$RANDOM$RANDOM

trap 'rm -f $tmpfile $tmpfile.c' EXIT

cat <<EOF >$tmpfile.c
#include <stdio.h>

int main()
{
    char c = 255;

    if (c > 128)
    {
        printf("unsigned\n");
    }
    else
    {
        printf("signed\n");
    }

    return 0;
}
EOF

$CC -o $tmpfile $tmpfile.c &&
$tmpfile
