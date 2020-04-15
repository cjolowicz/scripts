#!/bin/bash

set -euo pipefail

program=$(basename $0)
usage="\
usage:
       $program [URL]
       $program --delete
       $program --help

Dependencies:

   pipx install git-filter-repo
"
github_user=$USER
cookiecutter_project=$(pwd | xargs basename)
cookiecutter_package=${cookiecutter_project//-/_}
cookiecutter_url=$(git remote get-url origin)
project_name=${cookiecutter_project}-instance
package_name=${cookiecutter_package}_instance
replace_text=$(mktemp)

trap 'rm -f $replace_text' 0

cat <<EOF > $replace_text
$project_name==>{{cookiecutter.project_name}}
$package_name==>{{cookiecutter.package_name}}
EOF

message_callback='
import re

if not message:
    return message

pattern = re.compile(b" [(]#([0-9]+)[)]$")
replacement = b"\n\n'"$github_user/$project_name"'#\\1"

lines = message.splitlines(keepends=True)

if not pattern.search(lines[0]):
    return message

head = pattern.sub(replacement, lines[0])
body = b"".join(lines[1:])

return head + body
'

filter_options=(
    --force
    --refs=instance
    --to-subdirectory-filter='{{cookiecutter.project_name}}'
    --path-rename="$project_name:{{cookiecutter.project_name}}"
    --path-rename="$package_name:{{cookiecutter.package_name}}"
    --replace-text="$replace_text"
    --message-callback="$message_callback"
)

init() {
    if [ $# -eq 0 ]
    then
        url=${cookiecutter_url%.git}-instance.git
    else
        url="$1"
    fi

    git remote add instance $url
    git remote set-url --push instance none
}

fetch() {
    if ! git remote | grep -q '^instance$'
    then
        init "$@"
    fi

    branch=$(git rev-parse --abbrev-ref HEAD)

    git fetch --no-tags instance master
    git switch --force-create instance instance/master
    git filter-repo "${filter_options[@]}"

    git switch $branch
}

delete() {
    if git show-ref --verify --quiet refs/heads/instance
    then
        git branch --delete --force instance
    fi

    if git remote | grep -q '^instance$'
    then
        git remote remove instance
    fi
}

while [ $# -gt 0 ]
do
    if [ ${1::1} != - ]
    then
        break
    fi

    option="$1"
    shift

    case $option in
        --delete)
            delete
            exit
            ;;

        --help | -h)
            echo "$usage"
            exit
            ;;

        *)
            echo "$usage"
            exit 1
            ;;
    esac
done

fetch "$@"
