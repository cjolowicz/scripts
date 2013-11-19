#!/bin/bash

[ $# -gt 0 ] || set -- -index

for rfc
do
    {
        echo 
        wget -qO- http://tools.ietf.org/rfc/rfc$rfc.txt
    } | less -p 
done
