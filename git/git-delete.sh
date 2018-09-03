#!/bin/bash

set -e

program=$(basename $0)

commit=$1 ; shift

git rebase --preserve-merges --onto $commit^ $commit
