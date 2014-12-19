#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "\
usage: $prog [options] [patch]..
       $prog [options] [--all | --applied | --unapplied]
Update the patch description.

options:
    -a, --all              Rewrite all patches.
        --applied          Rewrite all applied patches.
        --unapplied        Rewrite all unapplied patches.
    -m, --message TEXT     Replace description with the specified message.
    -i, --from-stdin       Replace description with text read from standard input.
    -p, --prepend TEXT [+] Prepend text to the description.
    -A, --append TEXT  [+] Append text to the description.
    -s, --sed PROG     [+] Apply a sed(1) program to the description.
    -N, --from-name        Determine the description from the patch name.
    -#, --number           Append patch number to short descriptions.
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

    hg log --rev "\"$name\"" --template '{desc}' | grep -v $name
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

rewrite() {
    local name="$1"
    local desc=
    local item=
    local suffix=

    $dry_run || echo $name >&2

    qgoto $name

    if [ -n "$replace" ] ; then
        desc="$replace"
    elif $from_name ; then
        desc="$(sed -e 's,.,\U&,' -e 's,$,.,' -e 's,-, ,g' <<< $name)"
    else
        desc="$(read_desc $name)"
    fi

    for item in "${prepend[@]}" ; do
        desc="\
$item${desc:+

}$desc"
    done

    for item in "${append[@]}" ; do
        desc="\
$desc${desc:+

}$item"
    done

    if [ ${#sed[@]} -gt 0 ] ; then
        desc="$(sed "${sed[@]}" <<< "$desc")"
    fi

    if $number ; then
        suffix=" (%0${#total_patches}d/%d)"
        suffix="$(printf "$suffix" "$patch_number" "$total_patches")"
        desc="$(sed -e "1s,\$,$suffix," <<< "$desc")"
    fi

    write_desc $name "$desc"
}

### command line #######################################################

cwd=
all=false
applied=false
unapplied=false
dry_run=false
from_name=false
from_stdin=false
number=false
replace=
append=()
prepend=()
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
            prepend+=("$1")
            shift
            ;;

        -A | --append)
            [ $# -gt 0 ] || missing_arg "$option"
            append+=("$1")
            shift
            ;;

        -i | --from-stdin) from_stdin=true ;;
        -# | --number) number=true ;;
        -a | --all) all=true ;;
        --applied) applied=true ;;
        --unapplied) unapplied=true ;;
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

total_patches=$#
patch_number=0

for patch ; do
    ((++patch_number))

    rewrite "$patch"
done

if ! $dry_run ; then
    if [ -n "$oldtop" ] ; then
	qgoto "$oldtop"
    else
	qpop --all
    fi
fi
