#!/usr/bin/env python

from __future__ import annotations

import collections
import dataclasses
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from typing import Iterator
from typing import List
from typing import TextIO
from typing import Tuple

import pyphen
import tqdm


# aspell -d de dump master | aspell -l de expand > de.dict

VOWELS = "AEIOUÄÖÜ"
SEMIVOWELS = "Y"
EXCLUDE = "ÂÊÉ"


@dataclass
class Syllable:
    onset: str = ""
    nucleus: str = ""
    coda: str = ""

    @classmethod
    def parse_onset(cls, text: str) -> Iterator[str]:
        for index, character in enumerate(text):
            if character in VOWELS:
                return

            if character in SEMIVOWELS:
                if index > 0 or text[index + 1 : index + 2] not in VOWELS:
                    return

            yield character

    @classmethod
    def parse_nucleus(cls, text: str) -> Iterator[str]:
        for character in text:
            if character not in VOWELS + SEMIVOWELS:
                return

            yield character

    @classmethod
    def parse_coda(cls, text: str) -> Iterator[str]:
        for character in text:
            if character in VOWELS + SEMIVOWELS:
                return

            yield character

    @classmethod
    def parse(cls, text: str) -> Syllable:
        rest = text
        onset = "".join(cls.parse_onset(rest))
        rest = rest[len(onset) :]
        nucleus = "".join(cls.parse_nucleus(rest))
        rest = rest[len(nucleus) :]
        coda = "".join(cls.parse_coda(rest))
        rest = rest[len(coda) :]
        if rest:
            raise ValueError(f"{text}: vowels after coda: {rest}")
        return cls(onset, nucleus, coda)


def syllabic_split(hyphenate: pyphen.Pyphen, word: str) -> List[Syllable]:
    positions = hyphenate.positions(word)
    positions = [0, *positions, len(word)]
    return [
        Syllable.parse(word[start:end]) for start, end in zip(positions, positions[1:])
    ]


@dataclass
class Histogram:
    onset: collections.Counter = dataclasses.field(default_factory=collections.Counter)
    nucleus: collections.Counter = dataclasses.field(default_factory=collections.Counter)
    coda: collections.Counter = dataclasses.field(default_factory=collections.Counter)

    def update(self, syllable: Syllable) -> None:
        self.onset[syllable.onset] += 1
        self.nucleus[syllable.nucleus] += 1
        self.coda[syllable.coda] += 1


def phonotactic_clusters(words: Iterable[str]) -> Histogram:
    histogram = Histogram()
    hyphenate = pyphen.Pyphen(lang="de")
    for word in words:
        word = word.upper()
        if any(character in word for character in EXCLUDE):
            continue
        try:
            for syllable in syllabic_split(hyphenate, word):
                histogram.update(syllable)
        except ValueError as error:
            pass  #print(f"{word}: {error}", file=sys.stderr)
    return histogram


def print_phonotactic_clusters(io: TextIO) -> None:
    words = tqdm.tqdm(io.read().splitlines())
    histogram = phonotactic_clusters(words)
    for attr in ("onset", "nucleus", "coda"):
        print(f"==> {attr} <==")
        for syllable, count in getattr(histogram, attr).most_common():
            if syllable and count > 1:
                print(f"{count:-10d} {syllable}")


def main() -> None:
    if sys.argv[1:]:
        with open(sys.argv[1]) as io:
            print_phonotactic_clusters(io)
    else:
        print_phonotactic_clusters(sys.stdin)


if __name__ == "__main__":
    main()
