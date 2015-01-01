#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $prog [options]

Replace changesets ( P ; Q ) by ( P + Q ; -Q ).

In effect, this operation reverses the tree sequence ( T1 ; T2 ),
where T1 is the result of applying P to the parent and T2 is the
result of applying Q to T1.

options:
    -v, --verbose     Be verbose.
    -n, --dry-run     Print commands instead of executing them.
    -h, --help        Display this message.
"
}

##
# Note that this operation is its own inverse, since
#
#   REVERSE( REVERSE( P ; -Q ) )
#   = REVERSE( P + Q ; -Q )
#   = ( P + Q + -Q ; --Q )
#   = ( P ; Q )
##

error() {
    echo "$prog: $*" >&2
    exit 1
}

bad_usage() {
    echo "$prog: $*" >&2
    echo "Try \`$prog --help' for more information." >&2
    exit 1
}

bad_option() {
    bad_usage "unrecognized option \`$1'"
}

verbose() {
    local level=$1
    shift

    if [ $verbose -lt $level ] ; then
        :
    elif [ $level -gt 0 ] ; then
        echo "$*" >&2
    elif [ $verbose -gt 0 ] ; then
        echo
        echo "$prog: $*" >&2
        echo
    else
        echo "$prog: $*" >&2
    fi
}

for alias in qpop qrefresh qfold qnew ; do
    unalias $alias 2>/dev/null || true
done

qpop() {
    if $dry_run ; then
        $run hg qpop --quiet "$@"
    else
        verbose 1 hg qpop --quiet "$@"
        $run hg qpop --quiet "$@" | (
            grep -Ev '^(now at:|patch queue now empty)' || true
        )
    fi
}

qrefresh() {
    if $dry_run ; then
        $run hg qrefresh "$@"
    else
        verbose 1 hg qrefresh "$@"
        $run hg qrefresh "$@"
    fi
}

qnew() {
    if $dry_run ; then
        $run hg qnew "$@"
    else
        verbose 1 hg qnew "$@"
        $run hg qnew "$@"
    fi
}

qfold() {
    if $dry_run ; then
        $run hg qfold "$@"
    else
        verbose 1 hg qfold "$@"
        $run hg qfold "$@"
    fi
}

### command line #######################################################

dry_run=false
verbose=0

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -v | --verbose) ((++verbose)) ; options+=(--verbose) ;;
        -n | --dry-run) dry_run=true ; options+=(--dry-run) ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] || bad_option "$1"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

hgroot="$(hg root)" ||
    error "not in a mercurial repository"

mqroot="$(hg root --mq)" ||
    error "no patch repository"

patch="$(hg qtop)" ||
    error "no patches applied"

[ $(hg status -q | wc -l) -eq 0 ] ||
    error "working directory has uncommitted changes"

file="$mqroot/$patch"

# Reset the changeset description.
desc="$(hg tip --template '{desc}')"
qrefresh --message=

# Fold ( P ; Q ) into ( P + Q ).
qpop
qfold --keep "$patch"

# Reverse ( Q ) to ( -Q ).
if $dry_run ; then
    $run patch --directory="$hgroot" --strip=1 --reverse '<' "$file"
else
    verbose 1 patch --directory="$hgroot" --strip=1 --reverse '<' "$file"
    $run patch --directory="$hgroot" --strip=1 --reverse < "$file"
fi

$run rm "$file"

if $dry_run ; then
    $run hg qnew --message="\"$desc\"" "$patch"
else
    verbose 1 hg qnew --message="\"$desc\"" "$patch"
    $run hg qnew --message="$desc" "$patch"
fi
