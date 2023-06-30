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


def setup_directories() -> tuple[Path, Path]:
    tmpdir = Path("/tmp/coverage-blame")  # XXX chosen by fair dice roll
    shutil.rmtree(tmpdir, ignore_errors=True)

    def mkdir(name: str) -> Path:
        path = tmpdir / name
        path.mkdir(parents=True, exist_ok=True)
        return path

    return mkdir("a"), mkdir("b")


def build_tree(coverage: dict[str, set[int]]) -> tuple[Path, Path]:
    adir, bdir = setup_directories()
    for filename, missing in coverage.items():
        apath, bpath = adir / filename, bdir / filename
        with apath.open(mode="w") as afile, bpath.open(mode="w") as bfile:
            with Path(filename).open() as io:
                for number, line in enumerate(io, start=1):
                    afile.write(line)
                    if number not in missing:
                        bfile.write(line)
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
