#!/usr/bin/env python3

import sys
import xml.dom.minidom

print(xml.dom.minidom.parseString(sys.stdin.read()).toprettyxml())
