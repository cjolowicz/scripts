#!/bin/bash

n=$((100 * $RANDOM / 32767))

url='http://ajax.googleapis.com/ajax/services/search/web?v=1.0'

curl --silent --get \
    --data-urlencode "q=$*" \
    --data-urlencode "rsz=large" \
    --data-urlencode "start=$n" \
    "$url" |
grep -Eo '"unescapedUrl":"[^"]*"' |
cut -d: -f2- |
cut -d\" -f2
