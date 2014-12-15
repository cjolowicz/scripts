#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [file]..
Show the differences between a reject file and its subject files.

options:
    -p, --strip N        Strip N components from each subject file.
    -d, --directory DIR  Directory where subject files are located.
    -h, --help           Display this message.
"
    exit
}

error() {
    echo "$prog: error: $*" >&2
    exit 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

### command line #######################################################

directory=.
strip=0
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -d | --directory)
            [ $# -gt 0 ] || missing_arg "$option"
            directory="$1"
            shift
            ;;

        -p | --strip)
            [ $# -gt 0 ] || missing_arg "$option"
            strip="$1"
            shift
            ;;

        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -gt 0 ] || bad_usage "missing argument"

### main ###############################################################

for rejectfile ; do
    grep ^--- $rejectfile |
    cut -c4- |
    while read file ; do
	if [ "$strip" -gt 0 ] ; then
            file="$(echo "$file" | cut -d/ -f"$((strip+1))"-)"
	fi

        if [ -n "$directory" -a "${file::1}" != / ] ; then
            file="$directory"/"$file"
        fi

        grep -v ^+ $rejectfile |
        cut -c2- |
        diff -u - $directory/$file
    done
done
