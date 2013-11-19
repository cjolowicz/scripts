#!/bin/bash

BACKUPDIR=$HOME/backups

usage () {
    echo "usage: $(basename $0) [-rzhd].. file.."
    exit $1
}

remove=no
compress=no
directory=$BACKUPDIR

while [ $# -gt 0 ]
do
    arg="$1"
    shift

    case $arg in
        -r | --remove) remove=yes ;;
        -d | --directory) directory="$1" ; shift ;;
        -z | --compress) compress=yes ;;
        -h | --help) usage 0 ;;
        --) set -- "$arg" "$@" ; break ;;
        -*) usage 2 ;;
        *) set -- "$arg" "$@" ; break ;;
    esac
done

[ $# -gt 0 ] || usage 2

for arg
do
    if ! [ -f "$arg" -o -d "$arg" ]; then
        echo "$arg: no such file or directory" >&2
        exit 1
    fi

    backup="$(basename $(realpath $arg))"-$(date '+%Y%m%d-%H%M%S')

    if [ $remove = yes ]; then
        mv "$arg" "$directory"/"$backup"
    else
        cp -r "$arg" "$directory"/"$backup"
    fi

    if [ $compress = yes ]; then
	if [ -f "$directory"/"$backup" ]; then
            gzip "$directory"/"$backup"
	else
            (
		if ! cd "$directory" >/dev/null 2>&1; then
		    echo "$directory: cannot chdir" >&2
		    exit 1
		fi
		tar zcf "$backup".tar.gz "$backup" --remove
            )
	fi
    fi
done
