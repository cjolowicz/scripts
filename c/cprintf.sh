#!/bin/bash

cexec <<EOF
printf("$@%c", $(while read -e line ; do echo -n $line, ; done ; echo " '\\n'"));
EOF
