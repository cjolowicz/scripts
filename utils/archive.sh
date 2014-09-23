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
.

options:
    -r, --remove-files   Remove files after archiving.
    -p, --progress       Display a progress bar.
    -h, --help           Display this message.
"
}

### command line #######################################################

yesno() {
    local reply=
    read -p "$prog: $*?" reply

    case ${reply::1} in Y|y)
        return 0 ;;
    esac

    return 1
}

bad_option() {
    echo "$prog: unrecognized option \`$1'" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

missing_arg() {
    echo "$prog: option \`$1' requires an argument" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

remove_files=false
progress=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -r | --remove-files) remove_files=true ;;
        -p | --progress) progress=true ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

### main ###############################################################

tar_opts=(--create --no-recursion)

if $remove_files ; then
    tar_opts+=(--remove-files)
fi

for file ; do
    archive="$file".tar.bz2

    [ ! -f "$archive" ] || yesno "overwrite \`$archive'" || continue

    if $progress ; then
        find "$file" -depth -print0 | pv -ps $(find "$file" -printf '\n' | wc -l)
    else
        find "$file" -depth -print0
    fi |
    xargs -0 tar "${tar_opts[@]}" |
    bzip2 > "$archive"
done
