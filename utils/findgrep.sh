#!/bin/bash

makepath() {
    case $1 in
        ./*) echo "$1" ;;
        /*) echo "$1" ;;
        *) echo ./"$1" ;;
    esac
}

grepopts=(--color=always)
findopts=()
exclude=()
glob=()
color=yes
while [ $# -gt 0 ]; do
    arg="$1"
    shift

    case $arg in
        --) set -- "$arg" "$@"; break ;;
        -o | --grep-opts) grepopts+=($1) ; shift ;;
        -O | --find-opts) findopts+=($1) ; shift ;;
        -p | --prune) findopts+=(-path $(makepath "$1") -prune -o) ; shift ;;
        -x | --exclude) exclude+=(! -path $(makepath "$1")) ; shift ;;
        -g | --glob) glob+=(-path $(makepath "$1")) ; shift ;;
        -n | --name) glob+=(-name "$1") ; shift ;;
        -C | --no-color) grepopts+=(--color=never) ;;
        -h | --help) exec cat $0 ;; # ;-)
        -*) exit 2 ;;
        *)  set -- "$arg" "$@"; break ;;
    esac
done

[ $# -gt 0 ] || exit 2

grepexpr="$1"
shift

findopts+=("${glob[@]}" "${exclude[@]}" -type f -print0)

[ $# -gt 0 ] || set -- .

if gfind </dev/null >/dev/null 2>&1 ; then
    find=gfind
else
    find=find
fi

if gxargs </dev/null >/dev/null 2>&1 ; then
    xargs=gxargs
else
    xargs=xargs
fi

for dir
do
    $find "$dir" "${findopts[@]}"
done |
$xargs -0r grep -n "${grepopts[@]}" "$grepexpr" . |
LESS=FSRX less
