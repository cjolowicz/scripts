#!/bin/bash

# Wrapper script for hg(1) in pyenv environments.
#
# This script invokes the hg(1) installed at the location specified in
# ~/.python-version, if pyenv finds no other hg in `pyenv root`. The
# purpose of this is to allow using a non-system hg(1) from inside a
# python 3 environment. At the time of writing, hg(1) still requires
# python 2.7.
#
# Install this script to ~/bin/hg and prepend ~/bin to PATH.
#
##

if [ "$1" = '--print-hg-path' ] ; then
    print_hg_path=true
else
    print_hg_path=false
fi

# Use `pyenv which hg`, if it is located in `pyenv root`.

PYENV_ROOT=$(pyenv root)
HG=$(pyenv which hg)

case $HG in
    $PYENV_ROOT/*)
        if $print_hg_path ; then
	    echo $HG
	    exit
	fi
        exec $HG "$@"
        ;;
esac

# Use hg(1) installed at the location specified by ~/python-version.

if [ -f ~/.python-version ] ; then
    prefix=$(pyenv prefix $(cat ~/.python-version))

    HG=$prefix/bin/hg

    if [ -x $HG ] ; then
        if $print_hg_path ; then
	    echo $HG
	    exit
	fi
        exec "$HG" "$@"
    fi
fi

# Use `which hg`, taking care to skip this wrapper script.

which --all hg | while read HG ; do
    case $HG in
        ~/bin/hg | ~/.pyenv/shims/hg)
            ;;

        *)
	    if $print_hg_path ; then
		echo $HG
		exit
	    fi
            exec "$HG" "$@"
            ;;
    esac
done

# There is no hg(1) on this system.

echo 'no suitable installation of hg(1) found' >&2
exit 1
