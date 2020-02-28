#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [<package>]..
Upgrade Python programs on PATH.

This program upgrades the Python packages providing the specified commands,
using pip. The commands must be on PATH, and have the same name as the Python
package.

For each package, the script searches for a command with the same name on PATH,
and determines the Python interpreter from its shebang. The program runs pip
with that interpreter, to ensure that the package is upgraded within the Python
installation that would also be used to run it.

options:
    -h, --help  Display this message.
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

### command line #######################################################

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
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

for package
do
    filename="$(which "$package")" || error "$package: not on PATH"

    python=$(sed -n '1s/^#!//p' "$filename")

    $python -V >/dev/null 2>&1 || error "$package: cannot execute interpreter \"$python\""

    $python -m pip install --upgrade "$package" || error "$package: upgrade failed"
done
