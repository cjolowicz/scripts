#!/usr/bin/env python
import itertools
import sys
from textwrap import dedent
from typing import Iterator


def main():
    good = fail = 0
    lines = itertools.chain(iter(sys.stdin), itertools.repeat(None))

    while True:
        line = next(lines)

        if line is None:
            break

        if not line.startswith("==> "):
            sys.stdout.write(line)
            continue

        header = [line]
        header.extend(itertools.islice(lines, 4))

        if header[-1] is not None and header[-1].startswith("The output is identical."):
            good += 1
            continue

        fail += 1
        for line in header:
            if line is not None:
                sys.stdout.write(line)

        if None in header:
            break

    sys.stdout.write(
        dedent(
            f"""
            --
            PASS {good}
            FAIL {fail}
            """
        )
    )


if __name__ == "__main__":
    main()
