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
    if hub release | grep -q "$version"
    then
        command=edit
    else
        command=create
    fi

    if $dry_run
    then
        echo "hub release $command --message=\"$(get_message $version)\" v$version"
    else
        hub release $command --message="$(get_message $version)" v$version
    fi
done
