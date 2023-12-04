#!/bin/bash

set -euo pipefail

function header() {
    echo
    rich "[b]$*[/b]" --rule
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

header "cjolowicz/dotfiles"
git-update ~/Code/github.com/cjolowicz/dotfiles

header "cjolowicz/scripts"
git-update ~/Code/github.com/cjolowicz/scripts master

header "Homebrew"
brew update && brew upgrade

header "pipx"
pipx upgrade-all --include-injected

header "pip"
py -m pip install --user --upgrade pip debugpy

header "Emacs"
git-update ~/.emacs.d develop
