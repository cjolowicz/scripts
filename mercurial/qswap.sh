#!/bin/bash

set -e

top="$(hg qtop)"

hg qpop
hg qpop

hg qpush --move "$top"
hg qpush
