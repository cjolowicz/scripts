#!/bin/bash

if [ "$1" == "--json" ]
then
    shift
    json=true
else
    json=false
fi

if [ $# -gt 1 ]
then
    headers=true
else
    headers=false
fi

function display() {
    if $json
    then
        jq -C . | less -R
    else
        jq -r '.releases | keys[]' | sort -V
    fi
}

for package
do
    if $headers
    then
        echo "==> $package <=="
    fi

    curl -fSsL https://pypi.python.org/pypi/$package/json | display
done
