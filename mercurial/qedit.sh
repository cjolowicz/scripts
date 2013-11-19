#!/bin/bash

set -e

if [ -z "$EDITOR" ] ; then
    editor="$EDITOR"
elif [ -z "$VISUAL" ] ; then
    editor="$VISUAL"
elif [ -x /usr/bin/editor ] ; then
    editor=/usr/bin/editor
else
    editor=vi
fi

hgroot="$(hg root)"

series="$hgroot/.hg/patches/series"

$EDITOR "$series"

