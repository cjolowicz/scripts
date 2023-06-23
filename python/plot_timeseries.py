import sys
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.dates import DateFormatter
from pandas.tseries.frequencies import to_offset

__pyproject__ = """
[project]
name = "plot-timeseries"
version = "0"
requires_python = ">=3.9"
dependencies = ["matplotlib", "pandas"]
scripts = {plot-timeseries = "plot_timeseries:main"}
authors = [{name = "GPT-4"}]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
"""


def read_data(file):
    data = []
    for line in file:
        timestamp, *value = line.strip().split()
        if value:
            data.append((timestamp, float(value[0])))
        else:
            data.append((timestamp, 1))

    df = pd.DataFrame(data, columns=["timestamp", "value"])
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True).dt.tz_localize(None)
    return df.set_index(pd.DatetimeIndex(df["timestamp"]))


def aggregate_data(data, freq):
    return data.resample(freq).agg({"value": "sum"})


def plot_data(data, window):
    fig, ax = plt.subplots()
    ax.bar(data.index, data["value"])
    ax.set_xlabel("Date")
    ax.set_ylabel("Value")
    ax.set_title(f"Time Series (Aggregated by {window})")
    ax.xaxis.set_major_formatter(DateFormatter("%Y-%m-%d %H:%M:%S"))
    fig.autofmt_xdate()
    plt.show()


def main():
    if len(sys.argv) < 2:
        print("Usage: python plot_timeseries.py <aggregation_window>")
        sys.exit(1)

    window = sys.argv[1]
    data = read_data(sys.stdin)
    data = aggregate_data(data, window)
    plot_data(data, window)
