#!/usr/bin/env python
from __future__ import annotations

import datetime
import os
import sys
import time
from collections import Counter
from typing import Iterator


import argparse
import httpx


def parse_link_header(response: httpx.Response) -> dict[str, int]:
    """Parse the Link header."""

    def _() -> Iterator[tuple[str, str]]:
        header = response.headers["Link"]
        for field in header.split(","):
            url, rel = field.split(";")
            url = url.strip().removeprefix("<").removesuffix(">")
            rel = rel.strip().removeprefix('rel="').removesuffix('"')
            yield rel, url

    return dict(_())


def parse_starred_at(response: httpx.Response) -> list[datetime.date]:
    """Parse the response."""

    def _() -> Iterator[datetime.date]:
        data = response.json()
        assert isinstance(data, list), f"got {data = }"
        for stargazer in data:
            assert isinstance(stargazer, dict)
            starred_at = stargazer["starred_at"]
            assert isinstance(starred_at, str)
            date = datetime.datetime.strptime(starred_at, "%Y-%m-%dT%H:%M:%SZ")
            yield date.date()

    return list(_())


def get_star_dates_page(
    url: str, *, token: str
) -> tuple[list[datetime.date], str | None]:
    """Download a URL."""
    print(url, file=sys.stderr)

    headers = {
        "Accept": "application/vnd.github.v3.star+json",
        "Authorization": f"token {token}",
    }
    response = httpx.get(url, headers=headers, params={"per_page": 100})
    response.raise_for_status()

    dates = parse_starred_at(response)
    rels = parse_link_header(response)
    return dates, rels.get("next")


def get_star_dates(repository: str, *, token: str) -> Iterator[datetime.date]:
    """Retrieve the star dates for a repository."""
    url: str | None = f"https://api.github.com/repos/{repository}/stargazers"
    while url is not None:
        dates, url = get_star_dates_page(url, token=token)
        yield from dates
        time.sleep(1)


def print_star_dates(
    repository: str, *, token: str, week: bool
) -> Iterator[datetime.date]:
    """Retrieve the star dates for a repository."""
    dates = get_star_dates(repository, token=token)
    if week:
        counter = Counter(sorted((date.year, date.isocalendar()[1]) for date in dates))
    else:
        counter = Counter(sorted(dates))
    for date, count in counter.items():
        print(f"{date} {count}")


def main() -> None:
    """Main entry point."""
    token = os.environ["GITHUB_TOKEN"]
    parser = argparse.ArgumentParser()
    parser.add_argument("repository")
    parser.add_argument("--week", action="store_true", default=False)
    args = parser.parse_args()

    print_star_dates(args.repository, token=token, week=args.week)


if __name__ == "__main__":
    main()
