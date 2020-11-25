#!/bin/bash

set -euo pipefail

repo=$1
shift

prefixes=(
    https://github.com/
    git@github.com:
)

for prefix in ${prefixes[@]}
do
    case $repo in
        ${prefix}*)
            repo=${repo#$prefix}
            break
            ;;
    esac
done

owner=${repo%%/*}
repo=${repo#*/}

repodir=$HOME/Code/github.com/$owner/$repo
basedir=$(dirname $repodir)

mkdir -p $basedir
cd $basedir

if [ "$owner" = "$USER" ]
then
    git clone git@github.com:$owner/$repo
elif curl --head --fail --silent https://github.com/$USER/$repo >/dev/null
then
    git clone git@github.com:$USER/$repo
    git -C $repo remote add upstream git@github.com:$owner/$repo
else
    gh repo fork --clone=true $owner/$repo
fi

echo $repodir
