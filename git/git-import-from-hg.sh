#!/bin/bash

set -e

program=$(basename $0)

hg_options=()
git_options=()
sed_options=()

### functions ##########################################################

usage() {
    echo "usage: $program [options] hg-repo
Import a changeset from a mercurial repository into a git repository.

options:
    -t, --target=DIR   Specify the git repository (default: cwd).
    -r, --rev=CSET     Export the given changeset (default: tip).
    -m, --message=TEXT Use the given message as the commit message.
    -a, --author=TEXT  Use the given author as the commit author.
    -d, --date=TEXT    Use the given date as the commit date.
    -A, --no-author    Do not copy author information from the changeset.
    -D, --no-date      Do not copy date information from the changeset.
    -e, --edit         Edit the commit message.
    -s, --sed=PROG     Apply the given sed(1) program to the changeset (+).
    -n, --dry-run      Print commands instead of executing them.
    -c, --continue     Resume operation after conflict resolution.
    -h, --help         Display this message.

sed(1) programs use extended regular expressions.

Options marked by (+) may be specified multiple times.
"
}

error() {
    echo "$program: $*" >&2
    exit 1
}

bad_usage() {
    echo "$program: $*" >&2
    echo "Try \`$program --help' for more information." >&2
    exit 1
}

missing_arg() {
    bad_usage "option \`$1' requires an argument"
}

apply_sed() {
    if [ ${#sed_options[@]} -gt 0 ]
    then
	sed --regexp-extended "${sed_options[@]}"
    else
	cat
    fi
}

rewind() {
    if $dry_run
    then
	echo "git ${git_options[@]} apply - <<EOF"
	hg "${hg_options[@]}" export --git --rev "$rev" | apply_sed
	echo "EOF"
    else
	hg "${hg_options[@]}" export --git --rev "$rev" | apply_sed |
	    git "${git_options[@]}" apply --reject -
    fi
}

commit() {
    git_commit_options=(
	--all
	--message="$message"
    )

    if [ "$author" != "-" ]
    then
	git_commit_options+=(--author="$author")
    fi

    if [ "$date" != "-" ]
    then
	git_commit_options+=(--date="$date")
    fi

    $run git "${git_options[@]}" add --all
    $run git "${git_options[@]}" commit "${git_commit_options[@]}"

    if $edit
    then
	$run git "${git_options[@]}" commit --amend --edit
    fi
}

generate_message_from_patch_name() {
    patch=$(
	hg "${hg_options[@]}" log --rev "$rev" --template '{tags % "{tag}\n"}' |
	grep -Ev '^(tip|qtip|qbase)$')

    sed -e 's,.,\U&,' -e 's,$,.,' -e 's,-, ,g' <<< $patch
}

get_message() {
    desc="$(hg "${hg_options[@]}" log --rev "$rev" --template '{desc}')"

    case $desc in
	'imported patch'*)
	    generate_message_from_patch_name
	    ;;

	*)
	    echo "$desc"
	    ;;
    esac
}

get_author() {
    hg "${hg_options[@]}" log --rev "$rev" --template '{author}'
}

get_date() {
    hg "${hg_options[@]}" log --rev "$rev" --template '{date|isodate}'
}

### command line #######################################################

rev=tip
message=
author=
date=
edit=false
resume=false
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -t | --target)
            [ $# -gt 0 ] || missing_arg "$option"
            git_options+=(-C "$1")
            shift
            ;;

        -t*)
            git_options+=(-C "${option#-?}")
            ;;

        --target=*)
            git_options+=(-C "${option#--*=}")
            ;;

        -s | --sed)
            [ $# -gt 0 ] || missing_arg "$option"
            sed_options+=(-e "$1")
            shift
            ;;

        -s*)
            sed_options+=(-e "${option#-?}")
            ;;

        --sed=*)
            sed_options+=(-e "${option#--*=}")
            ;;

        -r | --rev)
            [ $# -gt 0 ] || missing_arg "$option"
            rev="$1"
            shift
            ;;

        -r*)
            rev="${option#-?}"
            ;;

        --rev=*)
            rev="${option#--*=}"
            ;;

        -m | --message)
            [ $# -gt 0 ] || missing_arg "$option"
            message="$1"
            shift
            ;;

        -m*)
            message="${option#-?}"
            ;;

        --message=*)
            message="${option#--*=}"
            ;;

        -a | --author)
            [ $# -gt 0 ] || missing_arg "$option"
            author="$1"
            shift
            ;;

        -a*)
            author="${option#-?}"
            ;;

        --author=*)
            author="${option#--*=}"
            ;;

        -d | --date)
            [ $# -gt 0 ] || missing_arg "$option"
            date="$1"
            shift
            ;;

        -d*)
            date="${option#-?}"
            ;;

        --date=*)
            date="${option#--*=}"
            ;;

        --no-author)
            author="-"
            ;;

        --no-date)
            date="-"
            ;;

        -c | --continue)
	    resume=true
	    ;;

        -e | --edit)
	    edit=true
	    ;;

        -n | --dry-run)
	    dry_run=true
	    ;;

        -h | --help)
	    usage
	    exit
	    ;;

        --)
	    break
	    ;;

        --* | -?)
	    bad_usage "unrecognized option \`$option'"
	    ;;

	-*)
	    set -- "${option::2}" -"${option:2}" "$@"
	    ;;

        *)
	    set -- "$option" "$@"
	    break
	    ;;
    esac
done

[ $# -gt 0 ] || bad_usage "missing argument"
hg_options+=(--cwd "$1")
shift

[ $# -eq 0 ] || bad_usage "unrecognized argument \`$1'"

### main ###############################################################

if $dry_run
then
    run=echo
fi

if [ -z "$message" ]
then
    message="$(get_message)"
fi

if [ -z "$author" ]
then
    author="$(get_author)"
fi

if [ -z "$date" ]
then
    date="$(get_date)"
fi

if ! $resume
then
    rewind
fi

commit
