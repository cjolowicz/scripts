#!/usr/bin/env python
import datetime
import sys


def main():
    n = int(sys.argv[1])
    now = (
        datetime.datetime.strptime(sys.argv[2], "%H:%M:%S")
        if len(sys.argv) > 2
        else datetime.datetime.now()
    )
    weight = (now.hour + (now.minute + now.second / 60) / 60) / 24
    expected = int(n / weight)
    print(f"{now:%H:%M:%S} {expected}")


if __name__ == "__main__":
    main()
