#!/usr/bin/env python
import sys
import os

sys.path.insert(0, os.path.expanduser("~/.poetry/lib"))  # noqa
from enum import Enum
from hashlib import sha256
import json
from typing import Iterator, Sequence, Tuple

from poetry.factory import Factory
from poetry.utils._compat import Path
from poetry.utils.toml_file import TomlFile


def get_content_hash(poetry_file: Path) -> str:
    """
    Returns the sha256 hash of the sorted content of the pyproject file.
    """
    content = TomlFile(poetry_file).read()
    content = content["tool"]["poetry"]

    relevant_content = {
        key: content.get(key)
        for key in ["dependencies", "dev-dependencies", "source", "extras"]
    }

    data = json.dumps(relevant_content, sort_keys=True).encode()

    return sha256(data).hexdigest()


class State(Enum):
    """
    Parser state.

    Conflict markers look like this:

    [metadata]
    <<<<<<< HEAD
    content-hash = "0f0ba9b5f2db11d7d6459b4c64f067bba2aeabe9301cdee8b24c3c4978662edd"
    =======
    content-hash = "6fda8d08fad72650855a0d918e49ebadaf73a1cb77985582eec0768c3b05e489"
    >>>>>>> Upgrade to foobar 5.3.4
    """

    DEFAULT = ""
    METADATA = "[metadata]\n"
    CONTENT_HASH = 'content-hash = "'
    CONFLICT_OURS = "<<<<<<< "
    CONFLICT_SEPARATOR = "=======\n"
    CONFLICT_THEIRS = ">>>>>>> "


state_machine = {
    (State.DEFAULT, State.DEFAULT): [State.METADATA, State.DEFAULT],
    (State.DEFAULT, State.METADATA): [State.CONFLICT_OURS],
    (State.METADATA, State.CONFLICT_OURS): [State.CONTENT_HASH],
    (State.CONFLICT_OURS, State.CONTENT_HASH): [State.CONFLICT_SEPARATOR],
    (State.CONTENT_HASH, State.CONFLICT_SEPARATOR): [State.CONTENT_HASH],
    (State.CONFLICT_SEPARATOR, State.CONTENT_HASH): [State.CONFLICT_THEIRS],
    (State.CONTENT_HASH, State.CONFLICT_THEIRS): [State.DEFAULT],
    (State.CONFLICT_THEIRS, State.DEFAULT): [State.DEFAULT],
}


def parse_line(line: str, previous: State, state: State) -> Tuple[State, State]:
    """
    Parse a single line in the lock file.
    """
    next_states = state_machine[previous, state]

    for next_state in next_states:
        if line.startswith(next_state.value):
            return state, next_state

    message = "expected {}".format(next_states[0].value)
    raise ValueError(message)


def parse_lock_file(lines: Sequence[str], content_hash: str) -> Iterator[str]:
    """
    Parse the lock file, resolving any content-hash conflict.
    """
    state = previous = State.DEFAULT

    for line in lines:
        previous, state = parse_line(line, previous, state)

        if state is State.DEFAULT:
            yield line
        elif state is State.CONFLICT_THEIRS:
            yield State.METADATA.value
            yield "".join((State.CONTENT_HASH.value, content_hash, '"\n'))


def merge_lock_file(lock_file: Path, content_hash: str) -> None:
    """
    Resolve merge conflict in the lock file, using the given content-hash.
    """
    with lock_file.open() as fp:
        lines = parse_lock_file(fp, content_hash)
        contents = "".join(lines)

    with lock_file.open(mode="w") as fp:
        fp.write(contents)


def main() -> None:
    """
    Resolve merge conflict for content-hash in poetry.lock.
    """
    poetry_file = Factory.locate(Path.cwd())
    content_hash = get_content_hash(poetry_file)

    lock_file = poetry_file.parent / "poetry.lock"
    merge_lock_file(lock_file, content_hash)


if __name__ == "__main__":
    main()
