#!/usr/bin/env pipx run
# /// script
# dependencies = ["tomli-w"]
# ///
import json
import sys
import tomli_w

if __name__ == "__main__":
    tomli_w.dump(json.load(sys.stdin), sys.stdout.buffer)
