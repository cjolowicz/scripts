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

### command line #######################################################

dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
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
$run hg qrefresh --message=

# Fold ( P ; Q ) into ( P + Q ).
$run hg qpop
$run hg qfold --keep "$patch"

# Reverse ( Q ) to ( -Q ).
if $dry_run ; then
    $run patch --directory="$hgroot" --strip=1 --reverse '<' "$file"
else
    $run patch --directory="$hgroot" --strip=1 --reverse < "$file"
fi

$run rm "$file"

if $dry_run ; then
    $run hg qnew --message="\"$desc\"" "$patch"
else
    $run hg qnew --message="$desc" "$patch"
fi
