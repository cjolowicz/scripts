#!/bin/bash

set -euo pipefail

script='
set -euo pipefail

for file
do
    message=$(realpath --relative-to=. "$file")
    git commit --message="$message" "$file"
done
'

git ls-files -z | xargs -0 fswatch -0 | xargs -0 -n1 bash -c "$script" "$0"
