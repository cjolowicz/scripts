"""Plot the timeseries data from a git repository."""
import matplotlib.pyplot as plt
from matplotlib.dates import DateFormatter


def truncate_to_week(timestamp: datetime.datetime) -> datetime.datetime:
    year, week, _ = timestamp.isocalendar()
    return timestamp.fromisocalendar(year, week, 1)


def truncate_to_month(timestamp: datetime.datetime) -> datetime.datetime:
    return datetime.datetime(timestamp.year, timestamp.month, 1)


def truncate_to_day(timestamp: datetime.datetime) -> datetime.datetime:
    return datetime.datetime(timestamp.year, timestamp.month, timestamp.day)


def create_truncate(
    args: argparse.Namespace,
) -> tuple[Callable[[datetime.datetime], datetime.datetime], int]:
    if args.month:
        return truncate_to_month, 30

    if args.week:
        return truncate_to_week, 7

    return truncate_to_day, 1


def read_series() -> list[datetime.datetime]:
    process = subprocess.run(
        ["git", "log", "--format=%at"], check=True, text=True, capture_output=True
    )
    return [
        datetime.datetime.fromtimestamp(int(line))
        for line in process.stdout.splitlines()
    ]


def aggregate_series(
    series: list[datetime.datetime],
    truncate: Callable[[datetime.datetime], datetime.datetime],
) -> dict[datetime.datetime, int]:
    data = defaultdict(int)
    for timestamp in series:
        data[truncate(timestamp)] += 1
    return data


def plot_series(data: dict[datetime.datetime, int], width: int) -> None:
    formatter = DateFormatter("%Y-%m-%d")

    plt.bar(data.keys(), data.values(), width=width)
    plt.gcf().autofmt_xdate()
    plt.gca().xaxis.set_major_formatter(formatter)
    plt.show()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.strip())

    parser.add_argument("--week", "-w", action="store_true")
    parser.add_argument("--month", "-m", action="store_true")

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    truncate, width = create_truncate(args)
    series = read_series()
    data = aggregate_series(series, truncate)

    plot_series(data, width)


__pyproject__ = """
[project]
name = "git-timeseries"
version = "0"
requires_python = ">=3.9"
dependencies = ["matplotlib"]
scripts = {git-timeseries = "git_timeseries:main"}

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
"""
