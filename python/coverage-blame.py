#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
from pathlib import Path


def main() -> None:
    tmpdir = Path("/tmp/coverage-blame")
    shutil.rmtree(tmpdir, ignore_errors=True)
    adir, bdir = tmpdir / "a", tmpdir / "b"
    adir.mkdir(parents=True, exist_ok=True)
    bdir.mkdir(parents=True, exist_ok=True)

    process = subprocess.run(
        ["pipx", "run", "coverage", "json", "--fail-under=0", "-o-"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    data = json.loads(process.stdout)
    for filename, result in data["files"].items():
        with Path(filename).open() as io, (adir / filename).open(mode="w") as a, (
            bdir / filename
        ).open(mode="w") as b:
            missing = set(result["missing_lines"]) | {
                a for a, b in result["missing_branches"]
            }
            for lineno, line in enumerate(io, start=1):
                a.write(line)
                if lineno not in missing:
                    b.write(line)
    subprocess.run(
        [
            "delta",
            "--line-numbers",
            "--line-numbers-right-format=",
            str(adir.relative_to(tmpdir)),
            str(bdir.relative_to(tmpdir)),
        ],
        cwd=tmpdir,
    )


if __name__ == "__main__":
    main()
