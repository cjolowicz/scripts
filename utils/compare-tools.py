#!/usr/bin/env python

import argparse
import datetime
import difflib
import itertools
import shlex
import statistics
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pygments.lexers
import pygments.formatters


def pairwise(iterable):
    a, b = itertools.tee(iterable)
    next(b, None)
    return zip(a, b)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--command",
        "-c",
        metavar="COMMAND",
        dest="commands",
        action="append",
        help="command line (use '{}' for filename, omit for stdin)",
    )
    parser.add_argument(
        "--files-from",
        metavar="FILE",
        help="Read paths to files from this file.",
    )
    parser.add_argument(
        "files",
        nargs="*",
    )
    return parser.parse_args()


@dataclass
class Result:
    command: str
    returncode: int
    stdout: str
    stderr: str
    runtime: datetime.timedelta


def run_command(command: str, path: Path) -> Result:
    if "{}" in command:
        full_command = command.replace("{}", str(path))
    else:
        full_command = f"{command} < {path}"

    start = datetime.datetime.now()
    process = subprocess.run(
        full_command,
        shell=True,
        capture_output=True,
        text=True,
        errors="surrogateescape",
    )
    runtime = datetime.datetime.now() - start

    return Result(command, process.returncode, process.stdout, process.stderr, runtime)


def compare_results(a: Result, b: Result) -> None:
    failed = [result for result in (a, b) if result.returncode != 0]

    for result in failed:
        print(f"{result.command!r} exited with status {result.returncode}")
        print()
        print(result.stderr)

    if failed:
        return

    a_executable, b_executable = [shlex.split(result.command)[0] for result in (a, b)]

    if a.stdout == b.stdout:
        for result in (a, b):
            print(f"{result.runtime}  {result.command}")

        print()
        print("The output is identical.")

        return

    diff = "".join(
        difflib.unified_diff(
            a.stdout.splitlines(keepends=True),
            b.stdout.splitlines(keepends=True),
            fromfile=f"{a.runtime}",
            fromfiledate=a.command,
            tofile=f"{b.runtime}",
            tofiledate=b.command,
        )
    )

    formatted = pygments.highlight(
        diff,
        pygments.lexers.DiffLexer(),
        pygments.formatters.TerminalFormatter(),
    )

    print(formatted, end="")


def main() -> None:
    args = parse_args()
    paths = [Path(filename) for filename in args.files]

    if args.files_from:
        paths.extend(
            [
                Path(filename)
                for filename in Path(args.files_from).read_text().splitlines()
            ]
        )

    all_results = []

    for path in paths:
        print(f"==> {path} <==")

        results = [run_command(command, path) for command in args.commands]
        all_results.append(results)

        for a, b in pairwise(results):
            compare_results(a, b)

    print()
    print("--")

    for command in args.commands:
        seconds = statistics.mean(
            result.runtime.total_seconds()
            for results in all_results
            for result in results
            if result.command == command
        )
        runtime = datetime.timedelta(seconds=seconds)
        print(f"{runtime}  {command}")


if __name__ == "__main__":
    main()
