#!/bin/bash

exec jq -C . | less --no-init --quit-if-one-screen --RAW-CONTROL-CHARS --chop-long-lines
