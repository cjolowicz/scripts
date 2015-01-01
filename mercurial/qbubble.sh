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
    -r, --reverse     Move the top-most patch to the back.
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
#      [1] { } by removal of A and B
#      [2] { B } by application of B (*)
#      [3] { B -B } by reverse application of B
#      [4] { B -B A B } by application of A and B
#      [5] { B A } by fold of { -B A B }
#
#  Moving A towards the back:
#
#      [1] { A B -A } by reverse application of A (*)
#      [2] { A B -A --A } by reverse application of -A
#      [3] { B --A } by fold of { A B -A }
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

    local bcopy=$(hg qunapplied | head -n2 | tail -n1)

    [ "$bcopy" = COPY-$b ] ||
        error "unexpected patch \"$bcopy\", expected COPY-$b"
}

abort_front() {
    qrefresh --exclude "$hgroot"
    hg revert --all # { 0   | A B' }
    qpop            # {     | 0 A B' }
    qpush --move $a # { A   | 0 B' }
    qpush           # { A 0 | B' }
    qfold COPY-$b   # { A B }
}

finish_front() {
    reverse $b # { B" | -B" A B' }

    # Fold { -B" A B' } as A.
    qpush                        # { B" -B"   | A B' }
    qpush                        # { B" -B" A | B' }
    qfold COPY-$b                # { B" -B" A' }
    qrefresh --exclude "$hgroot" # { B" -B" 0 }
    qnew COPY-$a                 # { B" -B" 0 A' }
    qpop                         # { B" -B" 0 | A' }
    qpop                         # { B" -B"   | 0 A' }
    qpop                         # { B"       | -B" 0 A' }
    qpush --move $a              # { B" 0     | -B" A' }
    qfold REVERSE-$b             # { B" -B"   | A' }
    qfold COPY-$a                # { B" A" }
    qpop                         # { B" | A" }
}

start_back() {
    a=$(hg qtop)
    b=$(hg qnext)

    verbose 0 "$b"
                                 # { A       | B }
    qrefresh --exclude "$hgroot" # { 0       | B }
    qnew COPY-$a                 # { 0 A'    | B }
    qpop                         # { 0       | A' B }
    qpop                         # {         | 0 A' B }
    qpush --move COPY-$a         # { A'      | 0 B }
    qpush --move $b              # { A' B    | 0 }
    reverse COPY-$a              # { A' B    | -A 0 }
    qpush ||                     # { A' B -A | 0 }
        error "resolve conflicts and qrefresh, \`$prog --continue' to resume."
}

resume_back() {
    a=$(hg qnext)
    b=$(hg qprev)

    local acopy=$(hg qapplied | tail -n3 | head -n1)
    local arev=$(hg qtop)

    [ "$acopy" = COPY-$a ] ||
        error "unexpected patch \"$acopy\", expected COPY-$a"

    [ "$arev"  = REVERSE-COPY-$a ] ||
        error "unexpected patch \"$arev\", expected REVERSE-$acopy"
}

abort_back() {
    qpop            # { A' B | -A 0 }
    qpop            # { A'   | B -A 0 }
    qpop            # {      | A' B -A 0 }
    qpush --move $a # { 0    | A' B -A }
    qfold COPY-$a   # { A    | B -A }
    qpush           # { A B  | -A }
    qdelete REVERSE-COPY-$a # { A B }
}

finish_back() {
    qpush                         # { A' B -A 0 }
    reverse REVERSE-COPY-$a       # { A' B -A 0 | --A }
    qfold REVERSE-REVERSE-COPY-$a # { A' B -A A" }

    # Fold { A' B -A } as B.
    qpop                         # { A' B -A  | A" }
    qpop                         # { A' B     | -A A" }
    qfold REVERSE-COPY-$a        # { A' B'    | A" }
    qrefresh --exclude "$hgroot" # { A' 0     | A" }
    qnew COPY-$b                 # { A' 0 B'  | A" }
    qpop                         # { A' 0     | B' A" }
    qpop                         # { A'       | 0 B' A" }
    qpop                         # {          | A' 0 B' A" }
    qpush --move $b              # { 0        | A' B' A" }
    qfold COPY-$a                # { 0'       | B' A" }
    qfold COPY-$b                # { B"       | A" }
    qpush                        # { B" A" }
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

continue=false
abort=false
command=
verbose=0
dry_run=false
dest=
reverse=false

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

        -r | --reverse) reverse=true ;;
        -c | --continue) continue=true ;;
        -A | --abort) abort=true ;;
        -n | --dry-run) dry_run=true ;;
        -v | --verbose) ((++verbose)) ;;
        -q | --quiet) ((--verbose)) ;;
        -h | --help) usage ; exit ;;
        --) break ;;
        -*) bad_option $option ;;
        *) set -- "$option" "$@" ; break ;;
    esac
done

[ $# -eq 0 ] || bad_option "$1"

! $abort || ! $continue ||
    bad_usage "specified both \`--abort' and \`--continue'"

! $reverse || [ -z "$dest" ] ||
    bad_usage "specified both \`--dest' and \`--reverse'"

if $dry_run ; then
    run=echo
fi

### main ###############################################################

hgroot="$(hg root)" ||
    error "not in a mercurial repository"

[ $(hg status -q | wc -l) -eq 0 ] ||
    error "working directory has uncommitted changes"

qtop=$(hg qtop) 2>/dev/null ||
    error "no patches applied"

if $reverse ; then
    dest=$(hg qseries | tail -n1)

    [ "$dest" != "$qtop" ] || exit 0
else
    [ "$dest" != "$qtop" ] ||
        error "a patch cannot be its own predecessor"
fi

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
