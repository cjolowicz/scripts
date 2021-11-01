#!/usr/bin/env bash
# brew install entr

while :
do
    ref=$(git symbolic-ref HEAD)

    entr -s "git show --stat && nox $*" <<< ".git/$ref"

    if read -n1 -t.5 -s
    then
        break
    fi
done
