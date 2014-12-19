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
    -a, --applied          Rewrite all applied patches.
    -m, --message TEXT     Replace description with the specified message.
    -i, --from-stdin       Replace description with text read from standard input.
    -p, --prepend TEXT [+] Prepend text to the description.
    -A, --append TEXT  [+] Append text to the description.
    -s, --sed PROG     [+] Apply a sed(1) program to the description.
    -N, --from-name        Determine the description from the patch name.
        --cwd DIR          Change working directory.
    -n, --dry-run          Print commands instead of executing them.
    -h, --help             Display this message.

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

write_desc() {
    local name="$1"
    local desc="$2"

    if $dry_run ; then
        $run hg qrefresh --message="\"$desc\""
    else
        $run hg qrefresh --message="$desc"
    fi
}

from_name() {
    local name="$1"
    local desc=

    qgoto "$name"

    desc="$(hg log --rev "\"$name\"" --template '{desc}')"

    if [ -n "$desc" ] && [ "$desc" != "imported patch $name" ] && ! $force ; then
        error "description is already to set, use --force to override"
    fi

    desc="$(sed 's,.,\U&,;s,$,.,;s,-, ,g' <<< "$name")"

    write_desc "$name" "$desc"
}

rewrite() {
    local name="$1"
    local desc=

    $dry_run || echo "$name" >&2

    qgoto "$name"

    if $from_name ; then
        from_name "$name"
    fi

    if [ -n "$replace" ] ; then
        write_desc "$name" "$replace"
    fi

    if [ -n "$prepend" ] ; then
        write_desc "$name" "\
$prepend

$(read_desc $name)"
    fi

    if [ -n "$append" ] ; then
        write_desc "$name" "\
$(read_desc $name)

$append"
    fi

    if [ ${#sed[@]} -gt 0 ] ; then
        write_desc "$name" "$(read_desc $name | sed "${sed[@]}")"
    fi
}

### command line #######################################################

cwd=
applied=false
dry_run=false
from_name=false
from_stdin=false
replace=
append=
prepend=
sed=()
while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -m | --message)
            [ $# -gt 0 ] || missing_arg "$option"
            replace="$1"
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

        -p | --prepend)
            [ $# -gt 0 ] || missing_arg "$option"

            prepend="$1${prepend+

}$prepend"
            shift
            ;;

        -A | --append)
            [ $# -gt 0 ] || missing_arg "$option"

            append="$append${append+

}$1"
            shift
            ;;

        -i | --from-stdin) from_stdin=true ;;
        -a | --applied) applied=true ;;
        -N | --from-name) from_name=true ;;
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
    [ $# -gt 0 ] || bad_usage "no patch specified"
else
    [ $# -eq 0 ] || bad_usage "unexpected argument \`$1'"
    set -- $(hg qapplied)
fi

if $from_stdin ; then
    [ -z "$replace" ] || bad_usage "both \`--from-stdin' and \`--message' specified"

    replace="$(cat)"
fi

if $from_name ; then
    [ -z "$replace" ] || bad_usage "both \`--from-name' and \`--message' or \`--from-stdin' specified"
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
