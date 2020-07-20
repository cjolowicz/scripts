#!/bin/bash

set -euo pipefail

root="$(pyenv root)"

for package
do
    for path in "$root"/versions/*/bin/$package
    do
        bindir="$(dirname "$path")"
        "$bindir"/python -m pip uninstall $package
    done
done
