#!/bin/bash

prog=$(basename $0)

### usage ##############################################################

usage() {
    echo "\
usage: $prog [options] [patch]..
       $prog [options] --applied

Prepend a message to the patch descriptions.

options:
    -m, --message TEXT  Use text as commit message.
    -l, --logfile FILE  Read commit message from file.
    -n, --number        Append patch number to short descriptions.
    -a, --applied       Bundle all applied patches.
    -r, --rebundle      Replace first two lines of descriptions.
    -u, --unbundle      Delete first two lines of descriptions.
        --cwd DIR       Change working directory.
    -h, --help          Display this message.
"
    exit
}

### command line #######################################################

error() {
    echo "$prog: error: $*" >&2
    exit 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

missing_arg () {
    bad_usage "option \`$1' requires an argument"
}

unknown_option () {
    bad_usage "unrecognized option \`$1'"
}

cwd=
applied=false
number=false
rebundle=false
unbundle=false
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --cwd) [ $# -gt 0 ] || missing_arg "$option" ; cwd="$1" ; shift ;;
        -l | --logfile) [ $# -gt 0 ] || missing_arg "$option" ; logfile="$1" ; shift ;;
        -m | --message) [ $# -gt 0 ] || missing_arg "$option" ; message="$1" ; shift ;;
        -a | --applied) applied=true ;;
        -n | --number) number=true ;;
        -r | --rebundle) rebundle=true ;;
        -u | --unbundle) unbundle=true ;;
        -h | --help) usage ;;
        --) break ;;
        -*) unknown_option "$option" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

if [ -n "$cwd" ] ; then
    cd "$cwd"
fi

if ! $applied ; then
    [ $# -gt 0 ] || bad_usage "missing argument"
else
    [ $# -eq 0 ] || bad_usage "unexpected argument \`$1'"
    set -- $(hg qapplied)
fi

if $unbundle ; then
    [ -z "$message" ] || bad_usage "--unbundle and --message specified"
    [ -z "$logfile" ] || bad_usage "--unbundle and --logfile specified"
    ! $number || bad_usage "--unbundle and --number specified"
elif [ -n "$logfile" ] ; then
    [ -z "$message" ] || bad_usage "--logfile and --message specified"
    message="$(cat "$logfile")"
else
    [ -n "$message" ] || bad_usage "no commit message specified"
fi

### functions ##########################################################

print_suffix() {
    printf " (%0${#n}d/%d)" "$i" "$n"
}

_print_description() {
    if ! $unbundle ; then
        echo "$message"
        echo
    fi

    hg tip --template '{desc}' |

    if $rebundle || $unbundle ; then
        sed '1,2d'
    else
        cat
    fi
}

print_description() {
    _print_description |

    if $number ; then
        suffix="$(print_suffix)"
        sed -e "1s,\$,$suffix,"
    else
        cat
    fi
}

### main ###############################################################

i=0
n=$#

for patch ; do
    ((++i))

    qtop=$(hg qtop)

    if [ "$qtop" != "$patch" ] ; then
        hg qgoto "$patch" || exit $?
    fi

    hg qrefresh -m"$(print_description)"
done
