#!/bin/bash
# usage: github-outdated [FILES]
#
# Input lines have format `USER/REPO: VERSION`. Output lines have the format
# `USER/REPO: CURRENT → LATEST`. An output line is printed if the current
# version is not a prefix of the latest version.

baseurl=https://api.github.com

check_rate_limit() {
    remaining=$(curl -fSsL $baseurl/rate_limit | jq -r .resources.core.remaining)

    if [ "$remaining" -eq 0 ]
    then
        reset=$(curl -fSsL $baseurl/rate_limit | jq -r .resources.core.reset)
        reset="$(date --date=@$reset +%H:%M:%S)"

        echo "Hit rate limit, retry at $reset" >&2
        exit 1
    fi
}

awk -F: '{ print $1 " " $2 }' "$@" |
    while read repository version
    do
        check_rate_limit

        latest=$(curl -fSsL $baseurl/repos/$repository/releases/latest | jq -r .tag_name)

        if [ "$latest" == "${latest#$version}" ]
        then
            echo "$repository: $version → $latest"
        fi
    done
