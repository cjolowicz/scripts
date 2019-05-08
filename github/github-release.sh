#!/bin/bash

case $1 in
    -n | --dry-run)
        dry_run=true
        shift
        ;;

    -h | --help)
        echo "$0 VERSION.."
        exit
        ;;

    *)
        dry_run=false
        ;;
esac

get_message() {
    echo v$1
    echo
    sed -nr "/^## \\[?$1\\]? - /,/^(## |\\[)/p" CHANGELOG.md |
        sed '1d;$d'

    local url=$(sed -n "s/^\\[${1//./\\.}]: *//p" CHANGELOG.md)

    if [ -n "$url" ]
    then
        echo "[See commits]($url)"
    fi
}

for version
do
    if $dry_run
    then
        echo "hub release create --message=\"$(get_message $version)\" v$version"
    else
        hub release create --message="$(get_message $version)" v$version
    fi
done
