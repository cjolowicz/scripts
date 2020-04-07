#!/bin/bash

set -euo pipefail

program=$(basename $0)

### functions ##########################################################

usage() {
    echo "usage: $program [options] [<package>]..
Upgrade dependencies using Poetry.

This is a front-end to \`poetry update\`.

By default, the script determines outdated dependencies using \`poetry show
--outdated\`, and performs the following actions for every reported package:

    1. Switch to a new branch \`upgrade/<package>-<version>\`.
    2. Update the dependency.
    3. Commit the changes to pyproject.toml and poetry.lock.
    4. Push to origin (optional).
    5. Open a pull request or merge request (optional).

If no packages are specified on the command-line, all outdated dependencies are
upgraded.

This script requires the following tools:

    - Poetry
    - git
    - gh (optional, for \`--pull-request\`)

options:
    --install            Install dependency into virtual environment (default).
    --commit             Commit the changes to Git (default).
    --push               Push the changes to remote.
    --pull-request       Open a pull request.
    --merge-request      Open a merge request.
    --no-install         Do not install dependency into virtual environment.
    --no-commit          Do not commit the changes to Git.
    --no-push            Do not push the changes (default).
    --no-pull-request    Do not open a pull request (default).
    --no-merge-request   Do not open a merge request (default).
    -r, --remote=REMOTE  Specify the remote to push to (default: origin).
    -n, --dry-run        Just show what would be done.
    -h, --help           Display this message.
"
}

warn() {
    echo "$program: $*" >&2
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

### command line #######################################################

install=true
commit=true
push=false
pull_request=false
merge_request=false
remote=origin
dry_run=false

while [ $# -gt 0 ]
do
    option="$1"
    shift

    case $option in
        --install)
            install=true
            ;;

        --no-install)
            install=false
            ;;

        --commit)
            commit=true
            ;;

        --no-commit)
            commit=false
            ;;

        --push)
            push=true
            ;;

        --no-push)
            push=false
            ;;

        --pull-request)
            pull_request=true
            ;;

        --no-pull-request)
            pull_request=false
            ;;

        --merge-request)
            merge_request=true
            ;;

        --no-merge-request)
            merge_request=false
            ;;

        -r | --remote)
            [ $# -gt 0 ] || missing_arg "$option"
            remote="$1"
            shift
            ;;

        --remote=*)
            remote="${option#${option%%=*}=}"
            ;;

        -r*)
            remote="${option:2}"
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

        -?)
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

packages=("$@")

### main ###############################################################

# Return with success if the package was specified on the command-line, or if no
# packages were specified on the command-line.
is_requested() {
    local needle="$1"
    local element=

    if [ ${#packages[@]} -eq 0 ]
    then
        return 0
    fi

    for element in "${packages[@]}"
    do
        if [ "$element" == "$needle" ]
        then
            return 0
        fi
    done

    return 1
}

original_branch=$(git rev-parse --abbrev-ref HEAD)

git diff --quiet --exit-code || error "Working tree is not clean"

package_pattern="[a-z][-a-z0-9]*"
version_pattern="[0-9][.0-9a-z]*"
separator_pattern="[ (!)]*"
pattern="($package_pattern) +$separator_pattern($version_pattern) +($version_pattern) +"

poetry show --outdated --no-ansi |
    sed -nr "s/^$pattern.*/\1 \2 \3/p" |
    while read package oldversion version
do
    is_requested "$package" || continue

    if $dry_run
    then
        echo "$package: $oldversion → $version"
        continue
    fi

    echo "==> $package $version <=="
    echo

    branch="upgrade/$package-$version"
    upgrade_branch_existed=false

    if $commit || $push || $pull_request || $merge_request
    then
        if git show-ref --verify --quiet refs/heads/"$branch"
        then
            upgrade_branch_existed=true
            git switch "$branch"
        else
            git switch --create "$branch" master
        fi
    fi

    if $install
    then
        poetry update "$package"
    else
        poetry update --lock "$package"
    fi

    if git diff --quiet --exit-code pyproject.toml poetry.lock
    then
        package_modified=false
    else
        package_modified=true
    fi

    if ! $package_modified && ! $upgrade_branch_existed && ($commit || $push || $pull_request || $merge_request)
    then
        warn "Skipping $package $version (Poetry refused upgrade)"

        if [ "$(git rev-parse master)" = "$(git rev-parse $branch)" ]
        then
            git switch "$original_branch"
            git branch --delete "$branch"
        fi

        continue
    fi

    if $package_modified && $commit
    then
        git add pyproject.toml poetry.lock
        git commit --message="Upgrade to $package $version"
    fi

    if $push
    then
        push_options=(--set-upstream)

        if $merge_request
        then
            push_options+=(
                --push-option=merge_request.create
                --push-option=merge_request.title="Upgrade to $package $version"
                --push-option=merge_request.description="Upgrade $package from $oldversion to $version."
            )
        fi

        git push "${push_options[@]}" "$remote" "$branch"
    fi

    if $pull_request && ! gh pr list 2>/dev/null | grep -q "$branch"
    then
        gh pr create \
           --title="Upgrade to $package $version" \
           --body="Upgrade $package from $oldversion to $version."
    fi

    echo
done

if ! $dry_run && ($commit || $push || $pull_request || $merge_request)
then
    git switch "$original_branch"
fi
