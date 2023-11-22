#!/bin/bash

set -euo pipefail

[ $# -gt 0 ] || set -- -

if [ -t 1 ]
then
    rich --markdown --width=72 --force-terminal "$@" | LESS=FSRX less
else
    rich --markdown --width=72 "$@"
fi
