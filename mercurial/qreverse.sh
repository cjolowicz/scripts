#!/bin/bash

for patch ; do
    hg diff --git --reverse --change $patch |
    hg qimport --quiet --git --name REVERSE-$patch -
done
