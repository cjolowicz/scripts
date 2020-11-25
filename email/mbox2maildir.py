#!/usr/bin/env python

import mailbox
import sys
from pathlib import Path


def convert_mbox_to_maildir(path: Path):
    directory = path.parent / "{path.name}.d"
    for folder in ("tmp", "new", "cur"):
        (directory / folder).mkdir(parents=True)

    mbox = mailbox.mbox(path)
    maildir = mailbox.Maildir(directory)
    for index, message in enumerate(mbox):
        subject = message.get("Subject", "")
        print(f"{index:-8d} {subject}", file=sys.stderr)
        maildir.add(message)


def main():
    for arg in sys.argv[1:]:
        convert_mbox_to_maildir(Path(arg))


if __name__ == "__main__":
    main()
