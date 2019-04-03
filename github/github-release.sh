#!/bin/bash

case $1 in
    -n | --dry-run)
        hub='echo hub'
        shift
        ;;

    -h | --help)
        echo "$0 VERSION"
        exit
        ;;

    *)
        hub=hub
        ;;
esac

version="$1"
shift

get_message() {
    echo v$version
    echo
    sed -nr "/^## \\[?$version\\]? - /,/^(## |\\[)/p" CHANGELOG.md |
        sed '1d;$d'
}

$hub release create --message="$(get_message)" v$version
