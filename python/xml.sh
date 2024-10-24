#!/bin/bash

set -euo pipefail

python3 -IPc <<EOF | bat -pl xml
import sys
import xml.dom.minidom

print(xml.dom.minidom.parseString(sys.stdin.read()).toprettyxml())
EOF


