import ast
import sys
import hashlib
import subprocess
from pathlib import Path

from platformdirs import user_cache_path


DIGEST_SIZE = 32


def hash_path(path: Path) -> str:
    data = str(path)
    return hashlib.blake2b(data.encode(), digest_size=DIGEST_SIZE).hexdigest()


def read_pyproject(path: Path) -> str:
    module = ast.parse(path.read_text(), filename=str(path))
    for node in module.body:
        match node:
            case ast.Assign(
                targets=[ast.Name(id="__pyproject__")],
                value=ast.Constant(),
            ):
                return node.value.value
    sys.exit("{path}: __pyproject__ not found")


def main():
    if "--help" in sys.argv[1:] or len(sys.argv) < 3:
        sys.exit(f"usage: {sys.argv[0]} <command> <script>")

    command = sys.argv[1:-1]
    script = Path(sys.argv[-1]).resolve()
    script_hash = hash_path(script)
    cachedir = user_cache_path("extract-pyproject") / script_hash
    cachedir.mkdir(parents=True, exist_ok=True)
    symlink = cachedir / script.name
    if not symlink.is_symlink():
        symlink.symlink_to(script)
    text = read_pyproject(script)
    (cachedir / "pyproject.toml").write_text(text)
    subprocess.run([*command, str(cachedir)], check=True)


__pyproject__ = """
[project]
name = "extract-pyproject"
version = "0"
dependencies = ["platformdirs"]
scripts = {extract-pyproject = "extract_pyproject:main"}

[build-backend]
requires = ["hatchling"]
build-backend = "hatchling.build"
"""
