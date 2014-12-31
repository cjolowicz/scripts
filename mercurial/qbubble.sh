#!/bin/bash

set -e
set -o pipefail

prog=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $prog [options]

Move the top-most patch to the front. With \`--dest', reorder the
top-most patch until the specified patch precedes it.

When moving a patch towards the front, manual intervention may be
required to apply the patch. When moving a patch towards the back,
manual intervention may be required to reverse the patch. In both
cases, operation may be resumed by re-invoking the program with the
same options and \`--continue'.

options:
    -d, --dest PATCH  Reorder patch until this patch precedes it.
    -c, --continue    Resume after conflict resolution.
    -A, --abort       Abort the operation.
    -C, --command CMD Use command to check patch state.
    -v, --verbose     Be verbose.
    -q, --quiet       Be quiet.
    -n, --dry-run     Print commands instead of executing them.
    -h, --help        Display this message.
"
}

##
#  This program reverses the order of two patches { A B } as follows:
#
#  Moving B towards the front:
#
#      [1] { A B } => { } by removal of A and B
#      [2] { } => { B } by application of B (*)
#      [3] { B } => { B -B } by reverse application of B
#      [4] { B -B } => { B -B A B } by application of A and B
#      [5] { B -B A B } => { B A } by fold
#
#  Moving A towards the back:
#
#      [1] { A B } => { A B -A } by reverse application of A (*)
#      [2] { A B -A } => { A B -A --A } by reverse application of -A
#      [3] { A B -A --A } => { B --A } by fold
#
#  Steps marked with (*) may require manual intervention.
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

missing_arg () {
    bad_usage "option \`$1' requires an argument"
}

verbose() {
    local level=$1
    shift

    if [ $verbose -lt $level ] ; then
        :
    elif [ $level -ge 1 ] ; then
        echo "$*" >&2
    elif [ $verbose -gt 0 ] ; then
        echo
        echo "$prog: $*" >&2
        echo
    else
        echo "$prog: $*" >&2
    fi
}

for alias in qpush qpop qrefresh qnew qdelete qimport ; do
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

qnew() {
    if $dry_run ; then
        $run hg qnew "$@"
    else
        verbose 1 hg qnew "$@"
        $run hg qnew "$@"
    fi
}

qdelete() {
    if $dry_run ; then
        $run hg qdelete "$@"
    else
        verbose 1 hg qdelete "$@"
        $run hg qdelete "$@"
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

qfoldl() {
    command qfoldl "${options[@]}" "$@"
}

qfoldr() {
    command qfoldr "${options[@]}" "$@"
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
    qpush
}

duplicate() {
    if $dry_run ; then
        $run hg diff --git --change $1 \|
        qimport --quiet --git --name COPY-$1 -
    else
        verbose 1 hg diff --git --change $1 \|
        hg diff --git --change $1 |
        qimport --quiet --git --name COPY-$1 -
    fi
}

start_front() {
    a=$(hg qprev)
    b=$(hg qtop)
    bcopy=COPY-$b

    verbose 0 "$a"

    duplicate $b       # { A B | B' }
    qpop               # { A   | B B' }
    qpop               # {     | A B B' }
    qpush --move $b || # { B"  | A B' }
        error "resolve conflicts and qrefresh, \`$prog --continue' to resume."
}

resume_front() {
    a=$(hg qnext)
    b=$(hg qtop)
    bcopy=$(hg qunapplied | head -n2 | tail -n1)

    [ "$bcopy" = COPY-$b ] ||
        error "unexpected patch \"$bcopy\", expected COPY-$b"
}

abort_front() {
    qrefresh --exclude "$hgroot"
    hg revert --all # { 0      | A B' }
    qpop            # {        | 0 A B' }
    qpush --move $a # { A      | 0 B' }
    qpush           # { A 0    | B' }
    qpush           # { A 0 B' }
    qfoldl          # { A B }
}

finish_front() {
    reverse $b # { B" -B"      | A B' }
    qpush      # { B" -B" A    | B' }
    qpush      # { B" -B" A B' }
    qfoldl     # { B" -B" A' }
    qfoldr     # { B" A" }
    qpop       # { B" | A" }
}

start_back() {
    a=$(hg qtop)
    b=$(hg qnext)
    acopy=COPY-$a
    arev=REVERSE-$acopy

    verbose 0 "$b"
                                 # { A       | B }
    qrefresh --exclude "$hgroot" # { 0       | B } -- "0" is a zero patch with A's metainfo
    qnew $acopy                  # { 0 A'    | B }
    qpop                         # { 0       | A' B }
    qpop                         # {         | 0 A' B }
    qpush --move $acopy          # { A'      | 0 B }
    qpush --move $b              # { A' B    | 0 }
    reverse $acopy ||            # { A' B -A | 0 }
        error "resolve conflicts and qrefresh, \`$prog --continue' to resume."
}

resume_back() {
    a=$(hg qnext)
    b=$(hg qprev)
    acopy=$(hg qapplied | tail -n3 | head -n1)
    arev=$(hg qtop)

    [ "$acopy" = COPY-$a        ] ||
        error "unexpected patch \"$acopy\", expected COPY-$a"

    [ "$arev"  = REVERSE-$acopy ] ||
        error "unexpected patch \"$arev\", expected REVERSE-$acopy"
}

abort_back() {
    qpop            # { A' B | -A 0 }
    qpop            # { A'   | B -A 0 }
    qpop            # {      | A' B -A 0 }
    qpush --move $a # { 0    | A' B -A }
    qpush           # { 0 A' | B -A }
    qfoldl          # { A    | B -A }
    qpush           # { A B  | -A }
    qdelete $arev   # { A B }
}

finish_back() {
    qpush            # { A' B -A 0 }
    reverse $arev || # { A' B -A 0 --A }
        error "cannot reverse $arev"

    qfoldl # { A' B -A A" }
    qpop   # { A' B -A | A" }
    qfoldl # { A' B'   | A" }
    qfoldr # { B"      | A" }
    qpush  # { B" A" }
}

start() {
    $front && start_front || start_back
}

resume() {
    $front && resume_front || resume_back
}

abort() {
    $front && abort_front || abort_back
}

finish() {
    $front && finish_front || finish_back
}

do_swap() {
    start
    finish
}

do_continue() {
    resume
    finish
}

do_abort() {
    resume
    abort
}

do_command() {
    [ -n "$command" ] || return 0

    if $dry_run ; then
        $run eval "\"$command\""
    else
        $run eval "$command" ||
            error "command failed"
    fi
}

is_patch_in() {
    local command="$1"
    local patch="$2"
    local other=

    [ "$patch" != qparent ] || return 0

    for other in $(hg $command) ; do
        [ "$patch" != $other ] || return 0
    done

    return 1
}

previous() {
    local patch="$1"
    local previous=qparent

    if [ "$patch" != qparent ] ; then
        previous=$(hg qapplied -1 $patch 2>/dev/null) || previous=qparent
    fi

    echo $previous
}

### command line #######################################################

options=()
continue=false
abort=false
command=
verbose=0
dry_run=false
dest=

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -d | --dest)
            [ $# -gt 0 ] || missing_arg $option
            dest="$1"
            shift
            ;;

        -C | --command)
            [ $# -gt 0 ] || missing_arg $option
            command="$1"
            shift
            ;;

        -c | --continue) continue=true ;;
        -A | --abort) abort=true ;;
        -n | --dry-run) dry_run=true ; options+=(--dry-run) ;;
        -v | --verbose) ((++verbose)) ; options+=(--verbose) ;;
        -q | --quiet) ((--verbose)) ; options+=(--quiet) ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] || bad_option "$1"

! $abort || ! $continue ||
    bad_usage "specified both \`--abort' and \`--continue'"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

which qfoldl >/dev/null 2>&1 ||
    error "qfoldl not found"

which qfoldr >/dev/null 2>&1 ||
    error "qfoldr not found"

hgroot="$(hg root)" ||
    error "not in a mercurial repository"

[ $(hg status -q | wc -l) -eq 0 ] ||
    error "working directory has uncommitted changes"

qtop=$(hg qtop) 2>/dev/null ||
    error "no patches applied"

[ "$dest" != "$qtop" ] ||
    error "a patch cannot be its own predecessor"

[ -n "$dest" ] || dest=qparent

is_patch_in qseries "$dest" ||
    error "patch \`$dest' is not in series file"

is_patch_in qapplied "$dest" && front=true || front=false

if $abort ; then
    do_abort
    exit
fi

if $continue ; then
    do_continue
    do_command
fi

while [ "$dest" != $(previous) ] ; do
    do_swap
    do_command
done
