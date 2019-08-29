#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options]
Frobnicate a quux using a collection of foobars.

options:
    -c, --command=COMMAND      Run this command.
    -o, --output=FILE          Write to the specified file.
    -v, --verbose              Be verbose.
    -n, --dry-run              Print commands instead of executing them.
    -h, --help                 Display this message.
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

verbose=false
dry_run=false
output=
commands=()

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -o | --output)
            [ $# -gt 0 ] || missing_arg "$option"
            output="$1"
            shift
            ;;

        --output=*)
            output="${option#${option%%=*}=}"
            ;;

        -o*)
            output="${option:2}"
            ;;

        -c | --command)
            [ $# -gt 0 ] || missing_arg "$option"
            commands+=("$1")
            shift
            ;;

        --command=*)
            commands+=("${option#${option%%=*}=}")
            ;;

        -c*)
            commands+=("${option:2}")
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

[ $# -eq 0 ] || bad_usage "unrecognized argument \`$1'"

if $dry_run
then
    run=echo
elif $verbose
then
    run=verbose_run
else
    run=
fi

### main ###############################################################

for command in ${commands+"${commands[@]}"}
do
    $run $command
done
