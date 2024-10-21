#!/usr/bin/env uv run
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "xmlschema",
# ]
# ///
import argparse
import decimal
import json

import xmlschema


class DecimalEncoder(json.JSONEncoder):
    def default(self, o: object) -> object:
        if isinstance(o, decimal.Decimal):
            return str(o)
        return super().default(o)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("file")
    parser.add_argument("--schema")
    args = parser.parse_args()

    if args.schema:
        schema = xmlschema.XMLSchema(args.schema)
        data = schema.to_dict(args.file)
    else:
        data = xmlschema.to_dict(args.file)

    print(json.dumps(data, cls=DecimalEncoder))


if __name__ == "__main__":
    main()
