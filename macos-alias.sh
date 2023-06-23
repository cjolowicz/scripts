#!/bin/bash

source=$1
target=$2

if [ -d $target ]
then
	dirname=$target
	basename=$(basename $source)
else
	dirname=$(dirname $target)
	basename=$(basename $target)
fi

osascript <<EOF
tell application "Finder"
  set source to POSIX file "$source" as alias
  make new alias to source at POSIX file "$dirname"
  set name of result to "$basename"
end tell
EOF
