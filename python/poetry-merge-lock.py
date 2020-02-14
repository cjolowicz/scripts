#!/usr/bin/env python
import sys
import os

sys.path.insert(0, os.path.expanduser("~/.poetry/lib"))  # noqa
from enum import Enum
from hashlib import sha256
import json
import os
import tempfile
from typing import Any, Iterator, List, Optional, Sequence, Tuple

from poetry.factory import Factory
from poetry.packages.locker import Locker
from poetry.utils._compat import Path
from poetry.utils.toml_file import TomlFile
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


def load_file(toml_file: Path) -> Tuple[TOMLDocument, TOMLDocument]:
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

    def __init__(self, keys: List[tomlkit.api.Key]):
        message = "Merge conflict at {}".format(".".join(key.key for key in keys))
        super().__init__(message)


def merge_item(ours: Any, theirs: Any, keys: List[tomlkit.api.Key]) -> Any:
    """
    Merge items in TOML documents.

    * Arrays are concatenated.
    * Tables are merged recursively.
    * Any other values must be equal.

    Args:
        ours: Our version of the item.
        theirs: Their version of the item.
        keys: The list of keys leading to the item.

    Returns:
        The merged item.

    Raises:
        MergeConflictError: The items cannot be merged.
    """
    if isinstance(ours, list):
        if not isinstance(theirs, list):
            raise MergeConflictError(keys)

        for value in theirs:
            ours.append(value)

        return ours

    if isinstance(ours, dict):
        if not isinstance(theirs, dict):
            raise MergeConflictError(keys)

        for key, value in theirs.items():
            if key in ours:
                ours[key] = merge_item(ours[key], value, keys + [key])
            else:
                ours[key] = value

        return ours

    if ours != theirs:
        raise MergeConflictError(keys)

    return ours


def merge(ours: TOMLDocument, theirs: TOMLDocument) -> TOMLDocument:
    """
    Merge TOML documents.

    Args:
        ours: Our version of the document.
        theirs: Their version of the document.

    Returns:
        The merged TOML document.
    """
    document = ours.copy()

    for key, value in theirs.items():
        if key in document:
            document[key] = merge_item(document[key], value, [key])
        else:
            document[key] = value

    return document


def read_lock_file(lock_file: Path, content_hash: str) -> TOMLDocument:
    """
    Read the lock file, resolving any merge conflicts.

    Args:
        lock_file: Path to the lock file.
        content_hash: An SHA256 hash for the pyproject file.

    Returns:
        The merged TOML document.
    """
    ours, theirs = load_file(lock_file)

    for document in (ours, theirs):
        document["metadata"]["content-hash"] = content_hash

    return merge(ours, theirs)


def validate_lock_file(lock_file: Path, local_config: dict) -> None:
    """
    Validate the lock file.

    Args:
        lock_file: Path to the lock file.
        local_config: The ``tool.poetry`` section of the pyproject file.
    """
    locker = Locker(lock_file, local_config)
    locker.locked_repository(with_dev_reqs=True)


def write_lock_file(
    document: TOMLDocument, lock_file: Path, local_config: dict
) -> None:
    """
    Write the lock file to disk.

    Args:
        document: The contents to be written to disk.
        lock_file: The destination path.
        local_config: The ``tool.poetry`` section of the pyproject file.
    """
    with tempfile.NamedTemporaryFile(delete=False) as temporary:
        contents = document.as_string()
        temporary.write(contents)

    try:
        validate_lock_file(temporary.name, local_config)
    except:  # noqa
        os.unlink(temporary.name)
        raise
    else:
        os.replace(temporary.name, lock_file)


def read_local_config(poetry_file: Path) -> dict:
    """
    Load the ``tool.poetry`` section of the pyproject file.
    """
    document = TomlFile(poetry_file).read()
    return document["tool"]["poetry"]


def get_content_hash(config: dict) -> str:
    """
    Return the SHA256 hash of the sorted ``tool.poetry`` section.
    """
    contents = {
        key: config.get(key)
        for key in ["dependencies", "dev-dependencies", "source", "extras"]
    }

    data = json.dumps(contents, sort_keys=True).encode()

    return sha256(data).hexdigest()


def merge_lock_file(poetry_file: Path, lock_file: Path) -> None:
    """
    Resolve merge conflicts in the lock file.

    Args:
        poetry_file: Path to the pyproject file.
        lock_file: Path to the lock file.
    """
    config = read_local_config(poetry_file)
    content_hash = get_content_hash(config)
    document = read_lock_file(lock_file, content_hash)
    write_lock_file(document, lock_file, config)


def main() -> None:
    """
    Resolve merge conflicts in poetry.lock.
    """
    poetry_file = Factory.locate(Path.cwd())
    lock_file = poetry_file.parent / "poetry.lock"

    merge_lock_file(poetry_file, lock_file)


if __name__ == "__main__":
    main()
