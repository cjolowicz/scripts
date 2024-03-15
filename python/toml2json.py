#!/usr/bin/env python3
import json
import sys
import tomllib

if __name__ == "__main__":
    json.dump(tomllib.load(sys.stdin.buffer), sys.stdout)
