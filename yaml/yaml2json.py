#!/usr/bin/env python

import sys
import yaml
import json

data = yaml.safe_load(sys.stdin)

json.dump(data, sys.stdout, sort_keys=True, indent=2)

print()
