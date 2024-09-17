#!/bin/bash

set -euo pipefail

program=$(basename $0)
usage="\
usage: $program [<task>..]
       $program --list

options:

  -l, --list   list the available tasks
  -h, --help   show this message and exit
"

function header() {
    echo
    rich --emoji --width 72 "[b]$*[/b]" --rule
    echo
}

function git-update() {
    local directory="$1"
    shift

    [ $# -gt 0 ] || set -- main

    local branch="$1"
    shift

    (
        cd "$directory"

        local stash="${RANDOM}"

        if [ -n "$(git status --porcelain)" ]
        then
            git stash push --message="$stash"
        fi

        git fetch --prune --tags

        if git diff --quiet "$branch" origin/"$branch"
        then
            echo "Already up-to-date."
        else
            git log --patch --stat --reverse "$branch"..origin/"$branch"
            git pull --rebase
        fi

        if git stash list | grep --quiet "$stash"
        then
            git stash pop --index
            # Don't specify `$stash` to avoid this error:
            # fatal: log for 'refs/stash' only has 1 entries
        fi
    )
}

function do_dotfiles() {
    git-update ~/Code/github.com/cjolowicz/dotfiles
}

function do_scripts() {
    git-update ~/Code/github.com/cjolowicz/scripts master
}

function do_brew() {
    brew update
    brew upgrade
}

function do_pipx() {
    pipx upgrade-all --include-injected
}

function do_emacs() {
    echo >&2
    echo "==> Upgrading ~/.emacs... <==" >&2
    echo >&2

    git-update ~/.emacs.d develop

    echo >&2
    echo "==> Updating packages... <==" >&2
    echo >&2

    emacs --batch -l ~/.emacs.d/init.el --eval="(configuration-layer/update-packages t)"

    echo >&2
    echo "==> Upgrading packages... <==" >&2
    echo >&2

    emacs --batch -l ~/.emacs.d/init.el
}

function do_go() {
    local old=$(go version | cut -d' ' -f3)
    local new=$(curl --silent 'https://go.dev/VERSION?m=text' | grep -Eo 'go[0-9]+(\.[0-9]+)+')

    if [ "$old" = "$new" ]
    then
        echo "The local Go version ${old} is up-to-date."
    else
        echo "The local Go version is ${old}. A new release ${new} is available."

        release="${new}.darwin-arm64.tar.gz"

        tmpdir=$(mktemp -d)
        trap 'rm -rf $tmpdir' 0

        curl -L https://go.dev/dl/$release --output $tmpdir/$release
        rm -rf /usr/local/go
        tar -C /usr/local -xzf $tmpdir/$release

        go version
    fi
}

function do_volta() {
    curl https://get.volta.sh | bash
}

function do_rust() {
    rustup update
}

function do_cargo() {
    cargo install $(cargo install --list | awk '/:$/ { print $1; }')
}

function do_uv() {
    uv self update
    uv tool upgrade --all
}

tasks=(
    brew
    go
    emacs
    pipx
    dotfiles
    scripts
    volta
    rust
    cargo
    uv
)

case ${1:-} in
    --help | -h)
        echo "$usage" >&2
        exit
        ;;

    --list | -l)
        for task in "${tasks[@]}"
        do
            echo $task
        done

        exit
        ;;
esac

[ $# -gt 0 ] || set -- "${tasks[@]}"

status=0

for task
do
    if [[ " ${tasks[@]} " =~ " ${task} " ]]
    then
        header "$task"

        if ! do_$task
        then
            echo "task $task failed" >&2
            status=1
        fi
    else
        echo "unknown task: $task" >&2
    fi
done

sparkles=":sparkle: :sparkle: :sparkle:"

header " $sparkles  done  $sparkles "

exit $status
