#!/usr/bin/env python3
"""Convert between CSV and JSON Lines."""
import argparse
import csv
import json
import sys


def to_json(source, target):
    for data in csv.DictReader(source):
        print(json.dumps(data), file=target, flush=True)


def from_json(source, target):
    class Target:
        def write(self, s: str):
            target.write(s)
            target.flush()

    writer = csv.writer(Target())
    keys = None
    for line in source:
        data = json.loads(line)
        if keys is None:
            keys = list(data.keys())
            writer.writerow(keys)

        writer.writerow([data.get(key) for key in keys])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--format",
        default="json",
        help="output format, either 'json' or 'csv'",
    )
    args = parser.parse_args()

    if args.format == "json":
        to_json(sys.stdin, sys.stdout)
    elif args.format == "csv":
        from_json(sys.stdin, sys.stdout)
    else:
        sys.exit("unknown format: {args.format}")


if __name__ == "__main__":
    main()
