#!/bin/bash

set -euo pipefail

program=$(basename $0)
skeleton=../Template
placeholder=Template

### functions ##########################################################

usage() {
    echo "usage: $program [options] [file]..

Create a directory tree from each given file, using a skeleton directory.

Each file is moved into a directory tree copied from $skeleton, with
$placeholder in all file and directory names replaced by the extension-less
basename of the file. If a file $placeholder.* with the same filename extension
exists, the file is moved there. Otherwise, it is moved to the top-level
directory of the tree.

options:
    -v, --verbose  Be verbose.
    -n, --dry-run  Print commands instead of executing them.
    -h, --help     Display this message.
"
}

error() {
    echo "$program: $*" >&2
    exit 1
}

bad_usage() {
    echo "$program: $*" >&2
    echo "Try \`$program --help' for more information." >&2
    exit 1
}

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

run() {
    if $verbose || $dry_run
    then
        for arg
        do
            printf '%q ' "$arg"
        done
        echo
    fi

    if ! $dry_run
    then
        "$@"
    fi
}

### command line #######################################################

verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -v | --verbose)
            verbose=true
            ;;

        -n | --dry-run)
            dry_run=true
            ;;

        -h | --help)
            usage
            exit
            ;;

        --)
            break
            ;;

        -?)
            bad_usage "unrecognized option \`$option'"
            ;;

        -*)
            set -- "${option::2}" -"${option:2}" "$@"
            ;;

        *)
            set -- "$option" "$@"
            break
            ;;
    esac
done

### main ###############################################################

for file
do
    ext=${name##*.}

    name="$(basename "$file")"
    name="${name%.$ext}"

    # Use /bin/cp to ensure macOS directory icons are handled correctly.
    run /bin/cp -r "$skeleton" "$name"

    if $dry_run
    then
        rename=(rename --subst-all "$placeholder" "$name" --dry-run)
        copy=(printf 'cp %q %q\n' "$name.$ext")
    else
        rename=(rename --subst-all "$placeholder" "$name")
        copy=(cp "$name.$ext")
    fi

    find "$name" -depth -name "*${placeholder}*" -execdir "${rename[@]}" {} +
    find "$name" -type f -name "$name.$ext" -execdir "${copy[@]}" {} +

    if ! find "$name" -type f -name "$name.$ext" -exec false {} +
    then
        run cp "$name.$ext" "$name"
    fi

    run rm "$name.$ext"
done
