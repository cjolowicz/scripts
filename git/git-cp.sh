#!/bin/bash

set -euo pipefail

source="$1"
shift

destination="$1"
shift

hash=$(git ls-tree --format='%(objectname)' HEAD "$source")

git read-tree -u --prefix="$destination" $hash
