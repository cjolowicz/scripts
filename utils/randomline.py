#!/usr/bin/env python

import argparse
import random
import sys
from typing import TextIO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--lines",
        "-n",
        metavar="K",
        type=int,
        default=1,
        help="print K lines",
    )
    parser.add_argument(
        "files",
        nargs="*",
    )
    return parser.parse_args()


def sample(io: TextIO, k: int) -> None:
    for line in random.sample(list(io), k):
        sys.stdout.write(line)


def main(*args: str) -> None:
    args = parse_args()
    if not args.files:
        sample(sys.stdin, args.lines)

    for filename in args.files:
        if filename == "-":
            sample(sys.stdin, args.lines)
        else:
            with open(filename) as io:
                sample(io, args.lines)


if __name__ == "__main__":
    main()
