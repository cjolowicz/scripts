#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [patch]..
       $prog [options] --applied

options:
    -a, --applied   Rewrite all applied patches.
        --cwd DIR   Change working directory.
    -f, --force     Overwrite existing message.
    -n, --dry-run   Print commands instead of executing them.
    -h, --help      Display this message.
"
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
        hg qpop --quiet "$@" | (
            grep -v '^now at:' || true
        )
    fi
}

qgoto() {
    if ! $dry_run ; then
        hg qgoto --quiet "$@" 2>&1 | (
            grep -Ev '^(now at:|patch .* is empty|.* is already at the top)' || true
        ) >&2
    fi
}

rewrite() {
    local name="$1"
    local desc=

    qgoto "$name"

    desc="$(hg log --rev "\"$name\"" --template '{desc}')"

    if [ -n "$desc" ] && [ "$desc" != "imported patch $name" ] && ! $force ; then
        error "description is already to set, use --force to override"
    fi

    desc="$(sed 's,.,\U&,;s,$,.,;s,-, ,g' <<< "$name")"

    qdesc "${options[@]}" --message "$desc" "$name"
}

### command line #######################################################

cwd=
applied=false
dry_run=false
force=false
options=()
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

        -a | --applied) applied=true ;;
        -f | --force) force=true ;;
        -n | --dry-run) dry_run=true ; options+=(--dry-run) ;;
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

### main ###############################################################

which qdesc >/dev/null 2>&1 ||
    error "qdesc not found"

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
