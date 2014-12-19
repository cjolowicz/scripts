#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [patch]..
       $prog [options] --applied
Update the patch description.

options:
    -m, --message TEXT  Specify message instead of reading from stdin.
    -a, --applied       Rewrite all applied patches.
        --cwd DIR       Change working directory.
    -p, --prepend       Prepend text to the description.
    -A, --append        Append text to the description.
    -s, --sed PROG  [+] Apply a sed(1) program to the description.
    -n, --dry-run       Print commands instead of executing them.
    -h, --help          Display this message.

[+] marked option can be specified multiple times"
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

for alias in qpop qgoto ; do
    unalias $alias 2>/dev/null || true
done

qpop() {
    if $dry_run ; then
        $run hg qpop --quiet "$@"
    else
        $run hg qpop --quiet "$@" | (
            grep -v '^now at:' || true
        )
    fi
}

qgoto() {
    if $dry_run ; then
        $run hg qgoto --quiet "$@"
    else
        $run hg qgoto --quiet "$@" 2>&1 | (
            grep -Ev '^(now at:|patch .* is empty|.* is already at the top)' || true
        ) >&2
    fi
}

read_desc() {
    local name="$1"

    hg log --rev "\"$name\"" --template '{desc}'
}

rewrite() {
    local name="$1"
    local desc=

    $dry_run || echo "$name" >&2

    qgoto "$name"

    if $prepend ; then
        desc="\
$message

$(read_desc $name)"
    elif $append ; then
        desc="\
$(read_desc $name)

$message"
    elif [ ${#sed[@]} -gt 0 ] ; then
        desc="$(read_desc $name | sed "${sed[@]}")"
    else
        desc="$message"
    fi

    if $dry_run ; then
        $run hg qrefresh --message="\"$desc\""
    else
        $run hg qrefresh --message="$desc"
    fi
}

### command line #######################################################

message=
cwd=
applied=false
dry_run=false
append=false
prepend=false
sed=()
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -m | --message)
            [ $# -gt 0 ] || missing_arg "$option"
            message="$1"
            shift
            ;;

        --cwd)
            [ $# -gt 0 ] || missing_arg "$option"
            cwd="$1"
            shift
            ;;

        -s | --sed)
            [ $# -gt 0 ] || missing_arg "$option"
            sed+=(-e "$1")
            shift
            ;;

        -p | --prepend) prepend=true ;;
        -A | --append) append=true ;;
        -a | --applied) applied=true ;;
        -n | --dry-run) dry_run=true ;;
        -h | --help) usage ;;
        --) break ;;
        -*) bad_usage "unrecognized option \`$option'" ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

if $dry_run ; then
    run=echo
fi

if ! $applied ; then
    [ $# -gt 0 ] || bad_usage "missing argument"
else
    [ $# -eq 0 ] || bad_usage "unexpected argument \`$1'"
    set -- $(hg qapplied)
fi

if [ ${#sed[@]} -gt 0 ] ; then
    if $prepend || $append ; then
        bad_usage "\`--sed' cannot be specified with \`--prepend' or \`--append'"
    fi

    [ -z "$message" ] || bad_usage "both \`--sed' and \`--message' specified"
else
    if $prepend && $append ; then
        bad_usage "\`--prepend' cannot be specified with \`--append'"
    fi

    [ -n "$message" ] || message="$(cat)"
fi

### main ###############################################################

if [ -n "$cwd" ] ; then
    if $dry_run ; then
        $run cd "$cwd"
    fi

    cd "$cwd"
fi

hg root >/dev/null || error "no repository"
hg root --mq >/dev/null || error "no patch repository"

oldtop="$(hg qtop)" 2>/dev/null

for patch ; do
    rewrite "$patch"
done

if ! $dry_run ; then
    if [ -n "$oldtop" ] ; then
	qgoto "$oldtop"
    else
	qpop --all
    fi
fi
