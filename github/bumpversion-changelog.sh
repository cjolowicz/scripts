#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] <version>
Add release to CHANGELOG.md.

Modify CHANGELOG.md to add a section for the specified version to the top.
Entries under \"Unreleased\" are moved to the new section.

options:
    -d, --date=DATE   Use DATE instead of now (see date(1)).
    -f, --file=FILE   Use FILE instead of CHANGELOG.md.
    -v, --verbose     Be verbose.
    -n, --dry-run     Write to stdout instead of FILE.
    -h, --help        Display this message.
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

verbose_run() {
    echo "$@"
    "$@"
}

### command line #######################################################

date=now
file=CHANGELOG.md
verbose=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -f | --file)
            [ $# -gt 0 ] || missing_arg "$option"
            file="$1"
            shift
            ;;

        --file=*)
            file="${option#${option%%=*}=}"
            ;;

        -f*)
            file="${option:2}"
            ;;

        -d | --date)
            [ $# -gt 0 ] || missing_arg "$option"
            date="$1"
            shift
            ;;

        --date=*)
            date="${option#${option%%=*}=}"
            ;;

        -d*)
            date="${option:2}"
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

[ $# -gt 0 ] || bad_usage "missing argument <version>"

version=$1
shift

[ $# -eq 0 ] || bad_usage "unrecognized argument \`$1'"

### main ###############################################################

date=$(date -d "$date" +%Y-%m-%d)

tmpfile=$(mktemp $program.XXXXXX)
trap 'rm -f "$tmpfile"' 0

cat "$file" > "$tmpfile"

if $dry_run; then
    file=/dev/stdout
fi

IFS=
while read -r line
do
    case $line in
        '## [Unreleased]')
            echo "$line"
            echo "## [$version] - $date"
            ;;

        '[Unreleased]: '*)
            url=${line#*: }
            base_url=${url%/*}
            old_version=${url##*/v}
            old_version=${old_version%...*}

            echo "[Unreleased]: $base_url/v$version...HEAD"
            echo "[$version]: $base_url/v$old_version...v$version"
            ;;

        *)
            echo "$line"
            ;;
    esac
done < $tmpfile > "$file"
