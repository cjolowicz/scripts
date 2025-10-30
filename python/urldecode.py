#!/usr/bin/env python3
import sys
from urllib.parse import unquote_plus

sys.stdout.write(unquote_plus(sys.stdin.read()))
