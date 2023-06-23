# Idea

## Spec

- triple-quoted string at the top level of a Python module
- first statement after the module docstring, if any
- must start with pyproject.toml, followed by a newline
- no string prefixes (e.g. no f-string)
- the payload of the string is everything after the first newline

## Semantics

- behavior equivalent to a Python project with only two files:
  - the module, as-is
  - a pyproject.toml with contents from the "pyproject.toml-string"

## Use Cases

- run single file scripts with dependencies (and metadata)
- lightweight packaging for libraries (single-module distributions)

## Goals

- don't invent another (partial) metadata standard a la `__requires__`
- don't require execution: static metadata can be retrieved from AST

## Example 1

```python
# example.py
'''pyproject.toml
[project]
name = "example"
version = "0"
dependencies = ["rich"]
scripts = {example = "example:main"}

[build-backend]
requires = ["hatchling"]
build-backend = "hatchling.build"
'''

from rich import print

def main():
    print("It works!", style="bold")
```

## Example 2 (with module docstring)

```python
# example.py
"""Example script with embedded pyproject.toml."""

'''pyproject.toml
[project]
name = "example"
version = "0"
dependencies = ["rich"]
scripts = {example = "example:main"}

[build-backend]
requires = ["hatchling"]
build-backend = "hatchling.build"
'''

import argparse
from rich import print

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    print("It works!", style="bold")
```

## Note

The TOML can't use triple quotes of the same kind that encloses it. In the
example given above, you can only use `"""` in the TOML. If you want to use
`'''` in the TOML, you need to change the enclosing triple quotes to `"""`.

## Implementation

Primarily, I'd like to `pipx run example.py`. Some other use cases:

- pip install <script>
- pipx run <script>
- pipx install <script>
- pipx run build <script>

For now, since there's no tool support, we could write wrappers:

What the wrapper needs to do:

1. identify the pyproject.toml docstring using ast
2. write pyproject.toml and script to a (temporary or) cache directory
3. invoke the tool on that directory
   - `pip install <cachedir>`
   - `pipx run <cachedir>`
   - `pipx install <cachedir>`
   - `pipx run build <cachedir>`

Regarding actual tool support, there are many open questions.

- Should this be a more general standard?
- If so, which tools need to implement this? Build frontends? Build backends?
  Every tool that reads configuration from pyproject.toml?
- Can't we just keep tool support optional for most tools?
- What would an sdist look like?
- Can we support this via a pyproject.toml reading library?

If a "non-packaging" tool wants to support this, there are some questions. What
if you invoke, say, mypy on a bunch of files, and each has its own embedded
pyproject.toml with mypy configuration, how does mypy deal with that? But you
wouldn't run mypy across multiple projects and expect it to deal with multiple
mypy configurations either.

Let's look at some specific tools:

- build can use the temporary directory approach: build backends will just work
- if build backends support this, build can just read pyproject.toml-string

- pip install without editable installs - same

- if pip understands the format, we get pipx support for free (at least mostly)
- pipx update/reinstall will also just work

- editable installs: this will only work if the build backend also supports it
  - build backend's job to produce editable wheel (typically with .pth file)
  - we can't "trick" the build backend with a tmpdir
  - otherwise, it will put the tmpdir on sys.path

## Limitations

updates don't work with wrappers

- editable installs
- pipx update/reinstall
- pipx run (with cache expiry)

## Rejected Ideas

### Python modules with TOML front matter

- this would break backwards compatibility for everything that reads Python
- current proposal OTOH is valid python: tool support completely optional

### Remove pyproject.toml string before installation

- no strong opinion
- it seems safer to keep installed and source modules identical, e.g. coverage tools
- also then we don't need to rewrite code
- advantage would be removing runtime overhead, but that seems negligible

## Appendix: Syntax Highlighting in Editors

- emacs: mmm-mode
