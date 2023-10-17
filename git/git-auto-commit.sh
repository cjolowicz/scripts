#!/bin/bash

set -euo pipefail

program=$(basename $0)
usage="\
usage: $program [-n] [--dry-run] [--push] [--diff]
       $program [-h] --help
"
options=()
diff=false
dry_run=false
push=false

while [ $# -gt 0 ]
do
    case $1 in
        -h | --help)
            echo "$usage"
            exit
            ;;

        -n | --dry-run)
            options+=(--dry-run)
            dry_run=true
            shift
            ;;

        --diff)
            options+=(--diff)
            diff=true
            shift
            ;;

        --push)
            options+=(--push)
            push=true
            shift
            ;;

        *)
            break
            ;;
    esac
done

fswatch_options=(
    --print0
    --recursive
    --extended
    --exclude='\.(git|venv|mypy_cache)'
    --event Created
    --event Updated
    --event Removed
    --event Renamed
    --event MovedFrom
    --event MovedTo
    --event AttributeModified
)

xargs_options=(
    --max-args=1  # Avoid buffering.
    --null
    --no-run-if-empty
)

if [ $# -eq 0 ]
then
    fswatch "${fswatch_options[@]}" . |
        xargs "${xargs_options[@]}" git ls-files -z |
        xargs "${xargs_options[@]}" "$0" "${options[@]}"

    exit $?
fi

status="$(git status --porcelain --untracked=no)"
if [ -z "$status" ]
then
   exit
fi

if $dry_run
then
    run=echo
else
    run=
fi

for file
do
    if $diff
    then
        env DELTA_PAGER=cat git diff -- "$file"
    fi

    message="$(realpath --relative-to=. "$file")"
    $run git commit --message="$message" "$file"
done

if $push
then
    $run git push
fi
