#!/bin/bash

case $1 in
    '--bytes')
        shift
        bytes=true
        ;;

    *)
        bytes=false
        ;;
esac

if [ $# -gt 0 ]
then
    count=$1
    shift
fi

if $bytes
then
    dd if=/dev/urandom count=1 2>/dev/null | tr -d -c '[:graph:]' | cut -c-${count:-8}
else
    shuf --head-count=${count:-4} --random-source=/dev/urandom /usr/share/dict/words | xargs
fi
