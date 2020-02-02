#!/bin/bash

if [ $# -gt 1 ]
then
    show_repository=true
else
    show_repository=false
fi

for repository
do
    if $show_repository
    then
        echo -n "$repository "
    fi

    curl -fSsL https://api.github.com/repos/$repository/releases/latest |
        jq -r .tag_name
done
