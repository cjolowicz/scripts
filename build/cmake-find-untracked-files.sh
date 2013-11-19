#!/bin/bash

tracked=$(
    for list in $(find -name CMakeLists.txt)
    do
	egrep -o '([-/A-Za-z0-9_]+\.[hc]pp|Test[-/A-Za-z0-9_]+)' $list |
	sed -r -e 's;^(Test.*)\.cpp;\1;' \
               -e 's;^(Test.*)\.hpp;\1;' \
               -e 's;^(Test.*);\1.cpp;' \
               -e "s;.*;$(dirname $list)/&;" \
               -e 's;/+;/;g'
    done
)

for file in $(find -type f -name '*.*pp' | egrep -v '^\./\.hg/')
do
    if ! echo "$tracked" | grep -q "^$file\$"
    then
        echo "$file"
    fi
done
