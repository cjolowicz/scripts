"""Nox sessions for linting and type-checking."""

import nox

SOURCES = ["ai/ralph.py"]


@nox.session
def lint(session: nox.Session) -> None:
    """Run ruff linter."""
    session.install("ruff")
    session.run("ruff", "check", *SOURCES)


@nox.session
def format(session: nox.Session) -> None:
    """Check ruff formatting."""
    session.install("ruff")
    session.run("ruff", "format", "--check", *SOURCES)


@nox.session
def typecheck(session: nox.Session) -> None:
    """Run ty type checker."""
    session.install("ty")
    session.run("ty", "check", *SOURCES)
