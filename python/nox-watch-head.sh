#!/bin/bash
# brew install entr

while :
do
    ref=$(git symbolic-ref HEAD)

    entr -ps "git show --no-patch --stat && nox $*" <<< ".git/$ref"
done
