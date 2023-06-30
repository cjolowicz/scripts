#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any


def get_coverage() -> dict[str, set[int]]:
    process = subprocess.run(
        ["pipx", "run", "coverage", "json", "--fail-under=0", "-o-"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )

    data = json.loads(process.stdout)

    def missing(
        missing_lines: list[int],
        missing_branches: list[list[int]],
    ) -> set[int]:
        # There's no good way of representing missed branches in a diff.
        # Treat the origin as a missed line and ignore the destination.
        return set(missing_lines) | {n for n, _ in missing_branches}

    return {
        filename: missing(
            result["missing_lines"],
            result["missing_branches"],
        )
        for filename, result in data["files"].items()
    }


def setup_directories() -> None:
    tmpdir = Path("/tmp/coverage-blame")  # XXX chosen by fair dice roll
    shutil.rmtree(tmpdir, ignore_errors=True)

    adir, bdir = tmpdir / "a", tmpdir / "b"
    adir.mkdir(parents=True, exist_ok=True)
    bdir.mkdir(parents=True, exist_ok=True)

    return adir, bdir


def build_tree(coverage: dict[str, set[int]]) -> tuple[Path, Path]:
    adir, bdir = setup_directories()
    for filename, missing in coverage.items():
        afile, bfile = adir / filename, bdir / filename
        with Path(filename).open() as io:
            with afile.open(mode="w") as a, bfile.open(mode="w") as b:
                for number, line in enumerate(io, start=1):
                    a.write(line)
                    if number not in missing:
                        b.write(line)
    return adir, bdir


def format_blame(adir: Path, bdir: Path) -> None:
    parent = adir.parent
    subprocess.run(
        [
            "delta",
            "--line-numbers",
            "--line-numbers-right-format=",
            str(adir.relative_to(parent)),
            str(bdir.relative_to(parent)),
        ],
        cwd=parent,
    )


def main() -> None:
    coverage = get_coverage()
    adir, bdir = build_tree(coverage)
    format_blame(adir, bdir)


if __name__ == "__main__":
    main()
