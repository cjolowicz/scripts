#!/bin/bash

cd "$(hg root)" &&
hg status --unknown --print0 --no-status | xargs --null rm --verbose
