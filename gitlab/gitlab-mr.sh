#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [--] [git-push-options]
Push to GitLab, creating a merge request.

options:
    -c, --create               Create a new merge request for the pushed branch.
    -t, --title=TEXT           Set the title of the merge request.
    -d, --description=TEXT     Set the description of the merge request.
    -l, --label=TEXT           Add labels to the merge request. If the label does not exist, it will be created.
    -u, --unlabel=TEXT         Remove labels from the merge request.
    -m, --merge                Set the merge request to merge when its pipeline succeeds.
    -r, --remove-branch        Set the merge request to remove the source branch when it’s merged.
    -T, --target=TEXT          Set the target of the merge request to a particular branch.
    -o, --open                 Open merge request URL in browser.
    -h, --help                 Display this message.
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

verbose_run() {
    echo "$@"
    "$@"
}

### command line #######################################################

options=()
open=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        -c | --create)
            options+=("--push-option=merge_request.create")
            ;;

        -o | --open)
            open=true
            ;;

        -m | --merge)
            options+=("--push-option=merge_request.merge_when_pipeline_succeeds")
            ;;

        -r | --remove-branch)
            options+=("--push-option=merge_request.remove_source_branch")
            ;;

        -t | --title)
            [ $# -gt 0 ] || missing_arg "$option"
            options+=("--push-option=merge_request.title=$1")
            shift
            ;;

        --title=*)
            options+=("--push-option=merge_request.title=${option#${option%%=*}=}")
            ;;

        -t*)
            options+=("--push-option=merge_request.title=${option:2}")
            ;;

        -d | --description)
            [ $# -gt 0 ] || missing_arg "$option"
            options+=("--push-option=merge_request.description=$1")
            shift
            ;;

        --description=*)
            options+=("--push-option=merge_request.description=${option#${option%%=*}=}")
            ;;

        -d*)
            options+=("--push-option=merge_request.description=${option:2}")
            ;;

        -l | --label)
            [ $# -gt 0 ] || missing_arg "$option"
            options+=("--push-option=merge_request.label=$1")
            shift
            ;;

        --label=*)
            options+=("--push-option=merge_request.label=${option#${option%%=*}=}")
            ;;

        -l*)
            options+=("--push-option=merge_request.label=${option:2}")
            ;;

        -u | --unlabel)
            [ $# -gt 0 ] || missing_arg "$option"
            options+=("--push-option=merge_request.unlabel=$1")
            shift
            ;;

        --unlabel=*)
            options+=("--push-option=merge_request.unlabel=${option#${option%%=*}=}")
            ;;

        -u*)
            options+=("--push-option=merge_request.unlabel=${option:2}")
            ;;

        -T | --target)
            [ $# -gt 0 ] || missing_arg "$option"
            options+=("--push-option=merge_request.target=$1")
            shift
            ;;

        --target=*)
            options+=("--push-option=merge_request.target=${option#${option%%=*}=}")
            ;;

        -T*)
            options+=("--push-option=merge_request.target=${option:2}")
            ;;

        -h | --help)
            usage
            exit
            ;;

        --)
            break
            ;;

        -? | --*)
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

### main ###############################################################

if $open
then
    tmpfile=$(mktemp)
    trap 'rm -rf $tmpfile' 0
    git push ${options+"${options[@]}"} "$@" 2>&1 | tee $tmpfile >&2
    url=$(grep -Eo 'https://.*/merge_requests/\w*' $tmpfile)
    python -c "import webbrowser; webbrowser.open('$url')"
else
    exec git push ${options+"${options[@]}"} "$@"
fi
