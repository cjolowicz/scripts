#!/usr/bin/env python
"""Browse the Python Standard Library reference.

Open the Python Standard Library reference [1] in the web browser. If
the name of a builtin, a standard library module, or a member of these
is provided, the browser will be pointed directly to its entry.

[1] https://docs.python.org/library/
"""
import argparse
import contextlib
import importlib
import sys
import webbrowser


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("name", nargs="?", help="builtin, module, or module member")
args = parser.parse_args()

baseurl = "https://docs.python.org/library"
if args.name is None:
    webbrowser.open(baseurl)
    sys.exit()

prefix = args.name.split(".")
suffix = []

while prefix:
    module = ".".join(prefix)
    with contextlib.suppress(ModuleNotFoundError, AttributeError):
        instance = importlib.import_module(module)
        for part in suffix:
            instance = getattr(instance, part)
        break
    suffix.insert(0, prefix.pop())

if not prefix:
    with contextlib.suppress(AttributeError):
        instance = __builtins__
        for part in suffix:
            instance = getattr(instance, part)
        module = "stdtypes"

    if module != "stdtypes":
        sys.exit(f"cannot import {args.name}")

url = f"{baseurl}/{module}.html"
if suffix:
    url = "#".join((url, args.name))

webbrowser.open(url)
