#!/bin/bash

set -euo pipefail

[ $# -eq 0 ] || exec "$0" < "$1"

program='
import sys
import xml.dom.minidom

print(xml.dom.minidom.parseString(sys.stdin.read()).toprettyxml())
'

python3 -IPc "$program" | expand -t2 | LESS=FSrX bat -pl xml
