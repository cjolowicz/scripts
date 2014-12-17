#!/bin/bash

prog=$(basename $0)

### functions ##########################################################

usage () {
    echo "usage: $prog [options] [REV]

Print the commit message for \`hg merge REV'.

options:
    -o, --output FILE       Write output to the specified file.
    -R, --repository REPO   Repository root directory or name of overlay bundle
                            file.
        --cwd DIR           Change working directory.
        --config CONFIG [+] Set/override config option. (use 'section.name=value')
        --encoding ENCODE   Set the charset encoding. (default: UTF-8)
        --encodingmode MODE Set the charset encoding mode. (default: strict)
        --color TYPE        When to colorize. (boolean, always, auto, or never)
                            (default: auto)
        --pager TYPE        When to paginate. (boolean, always, auto, or never)
                            (default: auto)
    -h, --help              Display this message.

[+] marked option can be specified multiple times
"
    exit
}

error () {
    echo "$prog: error: $*" >&2
    exit 1
}

bad_usage () {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

### command line #######################################################

options=()
output=/dev/stdout

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -o | --output)
            [ $# -gt 0 ] || bad_usage "option \`$option' requires an argument"
            output="$1"
            shift
            ;;

        -R | --repository    | \
             --cwd           | \
             --config        | \
             --encoding      | \
             --encodingmode  | \
             --color         | \
             --pager)
            [ $# -gt 0 ] || bad_usage "option \`$option' requires an argument"
            options+=("$option" "$1")
            shift
            ;;

        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -le 1 ] || bad_usage "unknown argument \`$2'"

### main ###############################################################

if [ $# -eq 0 ] ; then
    echo "Merge."
    echo
    merge-preview "${options[@]}" --template ' * {desc|firstline} [{node|short}]\n'
else
    echo "Merge $1 branch."
    echo
    merge-preview "${options[@]}" --template ' * [{branch}/{node|short}] {desc|firstline}\n' "$1" |
    sed "s,\\[$1/,[,"
fi > "$output"
