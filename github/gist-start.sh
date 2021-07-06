#!/bin/bash

set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf $tmpdir' 0

cd $tmpdir

[ $# -gt 0 ] || set -- README.md

filename="$1"
shift

"$EDITOR" "$filename"

url=$(gh gist create --public "$filename" | tail -n1)

gh gist clone "$url" ~/Code/gist.github.com/$(basename "$url")
