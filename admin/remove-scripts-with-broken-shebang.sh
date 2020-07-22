#!/bin/bash

find /usr/local/bin -not -type l -type f |
    while read file
    do
        shebang=$(head -n1 $file | cut -c3- | awk '{print $1}')
        if [ -n "$shebang" ] && [ ! -x "$shebang" ]
        then
            rm --interactive $file
        fi
    done

