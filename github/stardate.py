#!/usr/bin/env python
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import sys
import time
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from typing import Iterator

import platformdirs
import httpx


Results = list[dict[str, Any]]


@dataclass
class Page:
    """A page of results from the GitHub API."""

    url: str
    link: dict[str, str]
    etag: str
    results: Results
    cached: bool


def save_page_to_cache(page: Page) -> None:
    """Store page in the cache."""
    data = {
        "url": page.url,
        "link": page.link,
        "etag": page.etag,
        "results": page.results,
    }

    digest = hashlib.blake2b(page.url.encode()).hexdigest()
    cachedir = Path(platformdirs.user_cache_dir("stardate"))
    cache = cachedir / digest

    cachedir.mkdir(parents=True, exist_ok=True)
    with cache.open(mode="w") as io:
        json.dump(data, io)


def load_page_from_cache(url: str) -> Page | None:
    """Load results from the cache."""
    digest = hashlib.blake2b(url.encode()).hexdigest()
    cachedir = Path(platformdirs.user_cache_dir("stardate"))
    cache = cachedir / digest

    if not cache.is_file():
        return None

    with cache.open() as io:
        data = json.load(io)
        return Page(data["url"], data["link"], data["etag"], data["results"], True)


def parse_link_header(response: httpx.Response) -> dict[str, str]:
    """Parse the Link header."""

    def _() -> Iterator[tuple[str, str]]:
        header = response.headers["Link"]
        for field in header.split(","):
            url, rel = field.split(";")
            url = url.strip().removeprefix("<").removesuffix(">")
            rel = rel.strip().removeprefix('rel="').removesuffix('"')
            yield rel, url

    return dict(_())


def parse_starred_at(results: Results) -> list[datetime.datetime]:
    """Parse the response."""

    def _() -> Iterator[datetime.datetime]:
        assert isinstance(results, list), f"got {results = }"
        for stargazer in results:
            assert isinstance(stargazer, dict)
            starred_at = stargazer["starred_at"]
            assert isinstance(starred_at, str)
            yield datetime.datetime.fromisoformat(starred_at.replace("Z", "+00:00"))

    return list(_())


def request_stargazers(url: str, *, token: str, etag: str | None) -> httpx.Response:
    """Retrieve stargazers from the API."""
    print(url, file=sys.stderr)

    headers = {
        "Accept": "application/vnd.github.v3.star+json",
        "Authorization": f"token {token}",
    }

    if etag:
        headers |= {"If-None-Match": etag}

    response = httpx.get(url, headers=headers, params={"per_page": 100})
    if response.status_code != httpx.codes.NOT_MODIFIED:
        response.raise_for_status()

    return response


def get_stargazers_page(url: str, *, token: str) -> Page:
    """Retrieve stargazers from the cache or the API."""
    page = load_page_from_cache(url)
    etag = page.etag if page else None

    response = request_stargazers(url, token=token, etag=etag)

    if response.status_code != httpx.codes.NOT_MODIFIED:
        etag = response.headers["ETag"]
        link = parse_link_header(response)
        page = Page(url, link, etag, response.json(), False)
        save_page_to_cache(page)

    return page


def get_star_dates(repository: str, *, token: str) -> Iterator[datetime.datetime]:
    """Retrieve the star dates for a repository."""
    url: str | None = f"https://api.github.com/repos/{repository}/stargazers"
    page: Page | None = None

    while url is not None:
        if page and not page.cached:
            time.sleep(1)

        page = get_stargazers_page(url, token=token)

        yield from parse_starred_at(page.results)

        url = page.link.get("next")


def truncate(
    now: datetime.datetime, instant: datetime.datetime, interval: datetime.timedelta
) -> datetime.datetime:
    """Truncate an instant to the nearest interval."""
    delta = now - instant
    delta = interval * (delta // interval)
    return now - delta


def print_star_dates(
    repository: str, *, token: str, interval: datetime.timedelta
) -> None:
    """Print the star dates for a repository."""
    dates = get_star_dates(repository, token=token)
    now = datetime.datetime.now(datetime.timezone.utc)
    counter = Counter(sorted(truncate(now, date, interval) for date in dates))

    for date, count in counter.items():
        print(f"{date} {count}")


def parse_interval(interval: str) -> datetime.timedelta:
    """Parse a time interval."""
    if interval in ["Y", "year"]:
        return datetime.timedelta(days=365)

    if interval in ["m", "month"]:
        return datetime.timedelta(days=31)

    if interval in ["w", "week"]:
        return datetime.timedelta(weeks=1)

    if interval in ["d", "day"]:
        return datetime.timedelta(days=1)

    if interval in ["H", "hour"]:
        return datetime.timedelta(hours=1)

    if interval in ["M", "minute"]:
        return datetime.timedelta(minutes=1)

    if interval in ["S", "second"]:
        return datetime.timedelta(seconds=1)

    return datetime.timedelta(days=1)


def main() -> None:
    """Main entry point."""
    token = os.environ["GITHUB_TOKEN"]

    parser = argparse.ArgumentParser()
    parser.add_argument("repository")
    parser.add_argument("-i", "--interval")

    args = parser.parse_args()
    interval = parse_interval(args.interval)

    print_star_dates(args.repository, token=token, interval=interval)


if __name__ == "__main__":
    main()
