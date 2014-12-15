#!/bin/bash
#
# Replace changesets ( P ; Q ) by ( P + Q ; -Q ).
#
# In effect, this operation reverses the tree sequence ( T1 ; T2 ),
# where T1 is the result of applying P to the parent and T2 is the
# result of applying Q to T1.
#
# Note that this operation is its own inverse, since
#
#   REVERSE( REVERSE( P ; -Q ) )
#   = REVERSE( P + Q ; -Q )
#   = ( P + Q + -Q ; --Q )
#   = ( P ; Q )
#

set -e

hgroot="$(hg root)"
mqroot="$(hg root --mq)"
patch="$(hg qtop)"
file="$mqroot/$patch"

# Reset the changeset description.
desc="$(hg tip --template '{desc}')"
hg qrefresh -m ''

# Fold ( P ; Q ) into ( P + Q ).
hg qpop
hg qfold -k "$patch"

# Reverse ( Q ) to ( -Q ).
patch -d "$hgroot" -p1 -R < "$file"
rm "$file"
hg qnew -m"$desc" "$patch"
