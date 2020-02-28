#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [<package>]..
Upgrade Python programs on PATH.

This program upgrades the specified Python packages, using pip. Each package
must correspond to a command on PATH having the same name as the Python package,
unless overridden using the \`--command' option.

For each package, the program determines the Python interpreter used to run the
provided command. The program then upgrades the package using pip with that
interpreter, to ensure that the package is upgraded within the Python
installation that is also used to run it.

options:
    -c, --command  Specify the command associated with the package.
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

find_python() {
    local filename= python=

    filename="$(which "$1")" || error "$1: not on PATH"

    case $filename in
        */.pyenv/shims/*)
            filename="$(pyenv which "$1")"
            ;;
    esac

    python=$(sed -n '1s/^#!//p' "$filename")
    $python -V >/dev/null 2>&1 || error "$1: cannot execute interpreter \"$python\""

    echo "$python"
}

### command line #######################################################

command=

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -c | --command)
            [ $# -gt 0 ] || missing_arg "$option"
            command="$1"
            shift
            ;;

        --command=*)
            command="${option#${option%%=*}=}"
            ;;

        -c*)
            command="${option:2}"
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

if [ -n "$command" ]
then
    command_python="$(find_python "$command")"
else
    command_python=
fi

for package
do
    if [ -n "$command_python" ]
    then
        python="$command_python"
    else
        python="$(find_python "$package")"
    fi

    $python -m pip install --upgrade "$package" || error "$package: upgrade failed"
done
