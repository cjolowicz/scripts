#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [patch]..
       $prog [options] [--all | --applied | --unapplied]
Update the patch name using sed(1).

options:
    -e, --expression SCRIPT [+] Apply the specified script to the patch name.
    -a, --all                   Rewrite all patches.
        --applied               Rewrite all applied patches.
        --unapplied             Rewrite all unapplied patches.
        --cwd DIR               Change working directory.
    -n, --dry-run               Print commands instead of executing them.
    -h, --help                  Display this message.

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

rewrite() {
    local old="$1"
    local new="$(sed "${sed[@]}" <<< "$old")"

    if [ "$old" != "$new" ] ; then
        $dry_run || echo "\`$old' -> \`$new'" >&2
        $run hg qrename "$old" "$new"
    else
        $dry_run || echo "\`$old' unchanged." >&2
    fi
}

### command line #######################################################

cwd=
all=false
applied=false
unapplied=false
dry_run=false
sed=()
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --cwd)
            [ $# -gt 0 ] || missing_arg "$option"
            cwd="$1"
            shift
            ;;

        -e | --expression)
            [ $# -gt 0 ] || missing_arg "$option"
            sed+=(-e "$1")
            shift
            ;;

        -a | --all) all=true ;;
        --applied) applied=true ;;
        --unapplied) unapplied=true ;;
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

if $all ; then
    [ $# -eq 0 ] || bad_usage "unexpected argument \`$1'"

    set -- $(hg qseries)
elif $applied ; then
    [ $# -eq 0 ] || bad_usage "unexpected argument \`$1'"

    set -- $(hg qapplied)
elif $unapplied ; then
    [ $# -eq 0 ] || bad_usage "unexpected argument \`$1'"

    set -- $(hg qunapplied)
else
    [ $# -gt 0 ] || set -- $(hg qtop)
fi

[ $# -gt 0 ] || bad_usage "no patch specified"

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
