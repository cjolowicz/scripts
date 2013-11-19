#!/bin/sh
CACHE=$HOME/.dmenu_mancache
IFS=:
: ${MANPATH:=$(manpath)}

uptodate() {
	test ! -f $CACHE && return 1
	for dir in $MANPATH
	do
		test $dir -nt $CACHE && return 1
	done
	return 0
}

if ! uptodate
then
	for dir in $MANPATH
	do
		find $dir/ -type f -o -type l |
                sed -rn 's/\.[0-9][_A-Za-z0-9]*(\.gz)?$//p' |
                sed 's,.*/,,'
	done | sort | uniq > $CACHE.$$
	mv $CACHE.$$ $CACHE
fi

cat $CACHE
