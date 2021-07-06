#!/bin/bash

set -euo pipefail

version="$1"
shift

if ! git diff --quiet
then
    echo "there are uncommitted changes in the working tree" >&2
    exit 1
fi

if ! git diff --quiet --staged
then
    echo "there are uncommitted changes in the index" >&2
    exit 1
fi

remote=origin
default=$(git remote show $remote | sed -n 's/^ *HEAD branch: //p')

git switch $default

unpushed=($(git rev-list @{push}..))

if [ ${#unpushed[@]} -gt 1 ]
then
    echo "there are unpushed commits on $default" >&2
    exit 1
fi

git switch --create release-$version
poetry version $version
git add pyproject.toml
git commit --message=":bookmark: Release $version"
gh pr create --title="Release $version" --body=
