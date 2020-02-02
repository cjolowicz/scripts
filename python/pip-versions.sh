#!/bin/bash

if [ $# -gt 1 ]
then
    headers=true
else
    headers=false
fi

for package
do
    if $headers
    then
        echo "==> $package <=="
    fi

    curl -fSsL https://pypi.python.org/pypi/$package/json |
        jq -r '.releases | keys[]' |
        sort -V
done
