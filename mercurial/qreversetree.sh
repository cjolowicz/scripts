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

for alias in qpush qpop qrefresh qnew qfold qimport ; do
    unalias $alias 2>/dev/null || true
done

qpush() {
    if $dry_run ; then
        $run hg qpush --quiet "$@"
    else
        verbose 1 hg qpush --quiet "$@"
        $run hg qpush --quiet "$@" 2>&1 | (
            grep -Ev '^(now at:|patch .* is empty)' || true
        ) >&2
    fi
}

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

qimport() {
    if $dry_run ; then
        $run hg qimport --quiet "$@"
    else
        verbose 1 hg qimport --quiet "$@"
        $run hg qimport --quiet "$@" 2>&1 | (
            grep -Ev '^(adding .* to series file)' || true
        ) >&2
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

reverse() {
    if $dry_run ; then
        $run hg diff --git --reverse --change $1 \|
        qimport --quiet --git --name REVERSE-$1 -
    else
        verbose 1 hg diff --git --reverse --change $1 \|
        hg diff --git --reverse --change $1 |
        qimport --quiet --git --name REVERSE-$1 -
    fi
}

### command line #######################################################

options=()
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

reverse "$patch"       # { A B | -B }
qrefresh -X "$hgroot"  # { A 0 | -B }
qnew COPY-"$patch"     # { A 0 B' | -B }
qpop                   # { A 0 | B' -B }
qpop                   # { A | 0 B' -B }
qfold COPY-"$patch"    # { AB | 0 -B }
qpush                  # { AB 0 | -B }
qfold REVERSE-"$patch" # { AB -B }
