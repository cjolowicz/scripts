import argparse
import builtins
import json
import re

import gspread
from oauth2client.service_account import ServiceAccountCredentials


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", "-f")
    parser.add_argument("--path", "-p", dest="paths", action="append")
    parser.add_argument("location")
    return parser.parse_args()


def parse_path(path: str) -> tuple[re.Pattern[str], str]:
    data = json.loads(path)
    pattern = re.compile(data["sheet"])
    path = data["cell"]
    type = getattr(builtins, data["type"])
    return pattern, path, type


def main() -> None:
    args = parse_args()
    paths = [parse_path(path) for path in args.paths]
    credentials = ServiceAccountCredentials.from_json_keyfile_name(
        args.credentials,
        [
            "https://spreadsheets.google.com/feeds",
            "https://www.googleapis.com/auth/drive",
        ],
    )

    client = gspread.authorize(credentials)
    spreadsheet = client.open_by_url(args.location)
    worksheets = spreadsheet.worksheets()

    for sheet in worksheets:
        for pattern, path, type in paths:
            if pattern.match(sheet.title):
                cell = sheet.acell(path)
                value = type(cell.value)
                result = {"sheet": sheet.title, "value": value}
                print(json.dumps(result))
                break


__pyproject__ = """
[project]
name = "googlesheets"
version = "0"
dependencies = ["gspread", "oauth2client"]
scripts = {googlesheets = "googlesheets:main"}

[build-backend]
requires = ["hatchling"]
build-backend = "hatchling.build"
"""
