#!/bin/bash
# pipx install watchdog[watchmedo]

command=(
    nox
    --reuse-existing-virtualenvs
    "$@"
)

options=(
    --command="${command[*]}"
    --pattern='*.py'
    --ignore-pattern='*/.*'
    --recursive
    --wait
)

exec watchmedo shell-command "${options[@]}"
