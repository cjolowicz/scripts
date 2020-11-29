#!/usr/bin/env python

import collections
import sys
from pathlib import Path
from typing import Iterable
from typing import Iterator
from typing import TextIO
from typing import Tuple

import pyphen
import tqdm


# aspell -d de dump master | aspell -l de expand > de.dict

VOWELS = "AEIOUÄÖÜ"
SEMIVOWELS = "Y"
EXCLUDE = "ÂÊÉ"


def phonotactic_split(word: str) -> Iterator[str]:
    previous = -1
    for index, character in enumerate(word):
        if character in SEMIVOWELS:
            current = word[previous + 1 : index]
            if current:
                yield current
            yield character
            previous = index
        elif index > 0 and (
            (character in VOWELS) != (word[index - 1] in VOWELS)
        ):
            current = word[previous + 1 : index]
            if current:
                yield current
            previous = index
    current = word[previous + 1 :]
    if current:
        yield current


def syllabic_split(hyphenate: pyphen.Pyphen, word: str) -> Iterator[str]:
    positions = hyphenate.positions(word)
    positions = [0, *positions, len(word)]
    for start, end in zip(positions, positions[1:]):
        yield word[start:end]


def phonotactic_clusters(words: Iterable[str]) -> Iterable[Tuple[str, int]]:
    counter = collections.Counter()
    hyphenate = pyphen.Pyphen(lang="de")
    for word in words:
        word = word.upper()
        if any(character in word for character in EXCLUDE):
            continue
        for syllable in syllabic_split(hyphenate, word):
            for cluster in phonotactic_split(syllable):
                counter[cluster] += 1
    return counter.most_common()


def print_phonotactic_clusters(io: TextIO):
    words = tqdm.tqdm(io.read().splitlines())
    for syllable, count in phonotactic_clusters(words):
        if count > 1:
            print(f"{count:-10d} {syllable}")


def main():
    if sys.argv[1:]:
        with open(sys.argv[1]) as io:
            print_phonotactic_clusters(io)
    else:
        print_phonotactic_clusters(sys.stdin)


if __name__ == "__main__":
    main()
