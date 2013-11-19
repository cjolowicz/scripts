#!/bin/bash

baseurl=http://www.sgi.com/tech/stl

if [ $# -eq 0 ] ; then
    exec w3m -o confirm_qq=false $baseurl/table_of_contents.html
fi

for arg
do
    case $arg in
        vector|list|map|multimap|deque)
            arg=$(echo ${arg:0:1} | tr 'a-z' 'A-Z')${arg:1}
            ;;

        basic_string|string)
            arg=basic_string
            ;;

        *) ;;
    esac

    w3m -o confirm_qq=false $baseurl/$arg.html
done
