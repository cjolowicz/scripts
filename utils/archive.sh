#!/bin/bash
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# http://superuser.com/questions/656111

prog=$(basename $0)

### usage ##############################################################

usage() {
    echo "usage: $prog [options] [files]
Store the specified files in a compressed tar archive.

options:
    -o, --output FILE    Write to the specified file.
    -C, --directory DIR  Change to the specified directory.
    -r, --remove-files   Remove files after archiving.
    -p, --progress       Display a progress bar.
    -n, --dry-run        Print commands without executing them.
    -h, --help           Display this message.
"
}

### functions ##########################################################

error() {
    echo "$prog: $*" >&2
    exit 1
}

yesno() {
    local reply=
    read -p "$prog: $*? " reply

    case ${reply::1} in Y|y)
        return 0 ;;
    esac

    return 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

bad_option() {
    bad_usage "unrecognized option \`$1'"
}

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

pretty() {
    echo "$*" | fmt | sed '1b;s/^/    /' | sed '$b;s/$/ \\/'
}

### command line #######################################################

remove_files=false
progress=false
directory=
output=
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -o | --output) [ $# -gt 0 ] || missing_arg "$option" ; output="$1" ; shift ;;
        -C | --directory) [ $# -gt 0 ] || missing_arg "$option" ; directory="$1" ; shift ;;
        -r | --remove-files) remove_files=true ;;
        -p | --progress) progress=true ;;
        -n | --dry-run) dry_run=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -gt 0 ] || bad_usage "no input files specified"

### main ###############################################################

[ -z "$directory" ] || [ -d "$directory" ] ||
    error "no such directory: \`$directory'"

if [ -z "$output" ] ; then
    output="$(basename $1)".tar.bz2
fi

find_opts=("$@" -depth -print0)

tar_opts=(
    --create
    --no-recursion
    --null
    --bzip2
    --files-from=-
    --file=-
)

if $remove_files ; then
    tar_opts+=(--remove-files)
fi

if [ -n "$directory" ] ; then
    tar_opts+=(--directory="$directory")
fi

if $dry_run ; then
    [ -z "$directory" ] || pretty "cd $directory"

    pretty "find ${find_opts[@]} |"
    pretty "tar ${tar_opts[@]}"

    exit
fi

if [ -f "$output" ] ; then
    yesno "overwrite \`$output'" || exit
fi

(
    [ -z "$directory" ] || cd "$directory" >/dev/null

    find "${find_opts[@]}" |

    if $progress ; then
        pv -ps $(find "$@" -printf '\n' | wc -l)
    else
        cat
    fi |

    tar "${tar_opts[@]}"
) > "$output"
