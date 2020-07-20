#!/bin/bash
#
# Usage:
#
#   docker-vm-sh
#   docker-vm-sh <program> [<arguments>]
#
# Open a shell in the virtual machine running the Docker daemon on Mac and
# Windows. With arguments, run the specified program with the given arguments.
# Note that PATH is not searched, the full path to the program must be given.
#

exec docker run -it --rm --privileged --pid=host justincormack/nsenter1 "$@"
