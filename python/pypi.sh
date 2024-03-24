#!/bin/bash

set -euo pipefail

program=$(basename "$0")
api_url=https://pypi.org/simple
content_type=application/vnd.pypi.simple.v1+json
usage="\
usage: $program [<project>]
       $program --help
"

if [ $# -gt 0 ]
then
    case $1 in
        -h | --help)
            echo "$usage"
            exit
            ;;
    esac

    project="$1"
    shift

    # XXX normalize the project name
    path="/$project"
else
    path="/"
fi


function json() {
    if [ -t 1 ]
    then
        jq -C . | LESS=FSRX less
    else
        jq .
    fi
}

curl -fsSL -H "Accept: ${content_type}" "${api_url}${path}" | json
