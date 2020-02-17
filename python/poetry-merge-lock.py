#!/usr/bin/env python
import sys
import os

sys.path.insert(0, os.path.expanduser("~/.poetry/lib"))  # noqa
from collections import defaultdict
from enum import Enum
import itertools
import os
from typing import Any, Dict, Iterator, List, Optional, Sequence, Tuple

from poetry.factory import Factory
from poetry.packages import Package
from poetry.packages.locker import Locker
from poetry.utils._compat import Path
import tomlkit
import tomlkit.api
from tomlkit.toml_document import TOMLDocument


class Token(Enum):
    """
    Token for parsing files with merge conflicts.
    """

    CONFLICT_START = "<<<<<<< "
    CONFLICT_SEPARATOR = "=======\n"
    CONFLICT_END = ">>>>>>> "
    DEFAULT = ""


def tokenize(line: str) -> Token:
    """
    Return the token for the line.
    """
    for token in Token:
        if line.startswith(token.value):
            return token

    return Token.DEFAULT


class State(Enum):
    """
    Parser state for files with merge conflicts.
    """

    COMMON = 1
    OURS = 2
    THEIRS = 3


class UnexpectedTokenError(ValueError):
    """
    The parser encountered an unexpected token.
    """

    def __init__(self, token: Token):
        super().__init__("unexpected token {}".format(token))


state_transitions = {
    (State.COMMON, Token.CONFLICT_START): State.OURS,
    (State.OURS, Token.CONFLICT_SEPARATOR): State.THEIRS,
    (State.THEIRS, Token.CONFLICT_END): State.COMMON,
}


def parse_line(line: str, state: State) -> Tuple[Token, State]:
    """
    Parse a single line in a file with merge conflicts.

    Args:
        line: The line to be parsed.
        state: The current parser state.

    Returns:
        A pair, consisting of the token for the line, and the new parser state.

    Raises:
        UnexpectedTokenError: The parser encountered an unexpected token.
    """
    token = tokenize(line)

    for (valid_state, the_token), next_state in state_transitions.items():
        if token is the_token:
            if state is not valid_state:
                raise UnexpectedTokenError(token)
            return token, next_state

    return token, state


def parse_lines(lines: Sequence[str]) -> Iterator[Tuple[Optional[str], Optional[str]]]:
    """
    Parse a sequence of lines with merge conflicts.

    Args:
        lines: The sequence of lines to be parsed.

    Returns:
        A sequence of pairs. The first item in each pair is a line in
        *our* version, and the second, in *their* version. An item is
        ``None`` if the line does not occur in that version.

    Raises:
        ValueError: A conflict marker was not terminated.
    """
    state = State.COMMON

    for line in lines:
        token, state = parse_line(line, state)

        if token is not Token.DEFAULT:
            continue

        if state is State.OURS:
            yield line, None
        elif state is State.THEIRS:
            yield None, line
        else:
            yield line, line

    if state is not State.COMMON:
        raise ValueError("unterminated conflict marker")


def load_versions(toml_file: Path) -> Tuple[TOMLDocument, TOMLDocument]:
    """
    Load a pair of TOML documents from a TOML file with merge conflicts.

    Args:
        toml_file: Path to the lock file.

    Returns:
        A pair of TOML documents, corresponding to *our* version and *their*
        version.
    """

    def load(lines: Sequence[Optional[str]]) -> TOMLDocument:
        data = "".join(line for line in lines if line is not None)
        return tomlkit.loads(data)

    with toml_file.open() as fp:
        parse_result = parse_lines(fp)
        ours, theirs = zip(*parse_result)
        return load(ours), load(theirs)


class MergeConflictError(ValueError):
    """
    An item in the TOML document cannot be merged.
    """

    def __init__(self, keys: List[tomlkit.api.Key], ours: Any, theirs: Any):
        message = "Merge conflict at {}, merging {!r} and {!r}".format(
            ".".join(str(key) for key in keys), ours, theirs
        )
        super().__init__(message)


AnyDict = Dict[str, Any]
AnyDictList = List[AnyDict]


def merge_packages(ours: AnyDictList, theirs: AnyDictList) -> AnyDictList:
    packages = {}
    for package in itertools.chain(ours, theirs):
        value = packages.setdefault(package["name"], package)
        if package.value != value.value:
            raise MergeConflictError(["package"], value, package)

    return list(packages.values())


def merge_files(ours: AnyDict, theirs: AnyDict) -> AnyDict:
    files = tomlkit.table()
    for key in set(itertools.chain(ours, theirs)):
        our_value = ours.get(key)
        their_value = theirs.get(key)
        if None not in (our_value, their_value) and our_value != their_value:
            raise MergeConflictError(["metadata", "files", key], our_value, their_value)
        files[key] = our_value if our_value is not None else their_value
    return files


def merge_versions(ours: TOMLDocument, theirs: TOMLDocument) -> TOMLDocument:
    document = tomlkit.document()
    document["package"] = merge_packages(ours["package"], theirs["package"])
    document["metadata"] = {
        "files": merge_files(ours["metadata"]["files"], theirs["metadata"]["files"]),
    }
    return document


def activate_dependencies(packages: List[Package]) -> None:
    for package in packages:
        for dependency in package.requires:
            if dependency.is_optional():
                dependency.activate()


def load_packages(locker: Locker, lock_data: TOMLDocument) -> List[Package]:
    locker._lock_data = lock_data
    repository = locker.locked_repository(with_dev_reqs=True)
    activate_dependencies(repository.packages)
    return repository.packages


def merge_locked_packages(locker: Locker) -> List[Package]:
    lock_file = Path(locker.lock._path)
    ours, theirs = load_versions(lock_file)
    lock_data = merge_versions(ours, theirs)
    return load_packages(locker, lock_data)


def main() -> None:
    """
    Resolve merge conflicts in poetry.lock.
    """
    poetry = Factory().create_poetry(Path.cwd())
    packages = merge_locked_packages(poetry.locker)
    poetry.locker.set_lock_data(poetry.package, packages)


if __name__ == "__main__":
    main()
