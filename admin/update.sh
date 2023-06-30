#!/bin/bash

set -euo pipefail

function header() {
    echo
    rich "[b]$*[/b]" --rule
    echo
}

header "Homebrew"
brew update && brew upgrade

header "pipx"
pipx upgrade-all --include-injected

header "pip"
py -m pip install --user --upgrade pip debugpy

header "Spacemacs"
git -C ~/.emacs.d fetch

if ! git -C ~/.emacs.d diff --quiet develop origin/develop
then
    git -C ~/.emacs.d plog -p --stat --reverse develop..origin/develop
    git -C ~/.emacs.d pull
else
    echo "Already up-to-date."
fi