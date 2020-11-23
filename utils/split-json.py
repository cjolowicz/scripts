#!/usr/bin/env python

import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

while True:
    print(f"Reading file", file=sys.stderr)
    try:
        print(f"Loading JSON", file=sys.stderr)
        json.loads(text)
        break
    except json.JSONDecodeError as error:
        if error.msg != "Extra data":
            raise
        print(f"Inserting newline at position {error.pos}", file=sys.stderr)
        data = json.loads(text[: error.pos])
        print(
            f"Writing {error.pos} bytes, {len(text) - error.pos} remaining",
            file=sys.stderr,
        )
        json.dump(data, sys.stdout)
        print()
        text = text[error.pos :]

print("Done.", file=sys.stderr)
