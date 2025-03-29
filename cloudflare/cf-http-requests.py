#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "dateparser",
#     "httpx",
# ]
# ///
# ruff: noqa: EXE003, T201, ERA001
"""Retrieve Cloudflare HTTP requests via GraphQL."""

import argparse
import json
import os
import sys

import dateparser
import httpx

API_URL = "https://api.cloudflare.com/client/v4/graphql"

HTTP_REQUEST_FIELDS = [
    "cacheStatus",
    "clientASNDescription",
    "clientAsn",
    "clientCountryName",
    "clientDeviceType",
    "clientIP",
    "clientRequestHTTPHost",
    "clientRequestHTTPMethodName",
    "clientRequestHTTPProtocol",
    "clientRequestPath",
    "clientRequestQuery",
    "clientRequestScheme",
    "clientSSLProtocol",
    "datetime",
    "edgeResponseStatus",
    "originResponseDurationMs",
    "requestSource",
    "securityAction",
    "securitySource",
    "userAgent",
    "userAgentBrowser",
    "userAgentOS",
]


def parse_args() -> argparse.Namespace:
    """Parse the command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument(
        "--email",
        default=os.environ.get("CLOUDFLARE_API_EMAIL"),
        metavar="<email>",
        help="Cloudflare email address  [$CLOUDFLARE_API_EMAIL]",
    )
    parser.add_argument(
        "--key",
        default=os.environ.get("CLOUDFLARE_API_KEY"),
        metavar="<key>",
        help="Cloudflare API key  [$CLOUDFLARE_API_KEY]",
    )
    parser.add_argument(
        "--zone",
        default=os.environ.get("CLOUDFLARE_ZONE_ID"),
        metavar="<zone>",
        help="Cloudflare zone tag  [$CLOUDFLARE_ZONE_ID]",
    )
    parser.add_argument(
        "--from",
        "-f",
        default="1 day ago",
        dest="from_",
        metavar="<when>",
        help="start of time range in human-readable form  [1 day ago]",
    )
    parser.add_argument(
        "--to",
        "-t",
        default="now",
        metavar="<when>",
        help="end of time range in human-readable form  [now]",
    )
    parser.add_argument(
        "--dry-run",
        "-n",
        action="store_true",
        help="print the request body without sending",
    )
    return parser.parse_args()


def normalize_datetime(text: str) -> str:
    """Return the ISO8601 representation of a human-readable time."""
    settings = {"TO_TIMEZONE": "UTC", "RETURN_AS_TIMEZONE_AWARE": True}
    return dateparser.parse(text, settings=settings).replace(microsecond=0).isoformat()


def main() -> None:
    """Retrieve Cloudflare HTTP requests via GraphQL."""
    args = parse_args()
    headers = {"X-Auth-Email": args.email, "X-Auth-Key": args.key}
    query = f"""{{
      viewer {{
        zones(filter: {{ zoneTag: $zoneTag }}) {{
          httpRequestsAdaptive(
            filter: $filter
            limit: 10
            orderBy: [datetime_DESC]
          ) {{{" ".join(HTTP_REQUEST_FIELDS)}
          }}
        }}
      }}
    }}"""

    data = {
        "query": " ".join(query.split()),
        "variables": {
            "zoneTag": args.zone,
            "filter": {
                "datetime_geq": normalize_datetime(args.from_),
                "datetime_leq": normalize_datetime(args.to),
            },
        },
    }

    if args.dry_run:
        print(json.dumps(data))
        return

    response = httpx.post(API_URL, headers=headers, json=data)
    response.raise_for_status()

    match response.json():
        case {"data": {"viewer": {"zones": [{"httpRequestsAdaptive": records}]}}}:
            for record in records:
                print(json.dumps(record))

        case {"errors": [{"message": message}]}:
            sys.exit(message)


if __name__ == "__main__":
    main()
