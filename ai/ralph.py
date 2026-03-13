#!/usr/bin/env python3
"""Ralph Wiggum - Long-running AI agent loop."""

from __future__ import annotations

import argparse
import subprocess
import sys
import threading
import time
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import io


PROGRAM = "ralph"
SEPARATOR = "=" * 63
PROMPT_TEMPLATE = """\
<user-prompt>
{prompt}
</user-prompt>

<termination>
If there is truly nothing left to do at the START of this invocation, output
<promise>COMPLETE</promise> immediately and stop. Do NOT output
<promise>COMPLETE</promise> at the end of this invocation. This ensures that a fresh
invocation with a fresh context window confirms completion.
</termination>
"""


def print_message(text: str) -> None:
    """Print a user-facing message to stderr."""
    print(f"{PROGRAM}: {text}", file=sys.stderr)  # noqa: T201


def forward_lines(
    reader: io.TextIOWrapper,
    writer: io.TextIOWrapper,
    buf: list[str],
) -> None:
    """Forward lines from reader to writer, accumulating them in buf."""
    for line in reader:
        writer.write(line)
        writer.flush()
        buf.append(line)


def stream_command(cmd: list[str], input_data: str) -> tuple[str, str]:
    """Run a command, streaming stdout and stderr, and return both as strings."""
    proc = subprocess.Popen(  # noqa: S603
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    assert proc.stdin is not None  # noqa: S101
    assert proc.stdout is not None  # noqa: S101
    assert proc.stderr is not None  # noqa: S101

    proc.stdin.write(input_data)
    proc.stdin.close()

    stdout_lines: list[str] = []
    stderr_lines: list[str] = []

    stdout_thread = threading.Thread(
        target=forward_lines,
        args=(proc.stdout, sys.stdout, stdout_lines),
    )
    stderr_thread = threading.Thread(
        target=forward_lines,
        args=(proc.stderr, sys.stderr, stderr_lines),
    )

    stdout_thread.start()
    stderr_thread.start()
    stdout_thread.join()
    stderr_thread.join()
    proc.wait()

    return "".join(stdout_lines), "".join(stderr_lines)


def run_iteration(tool: str, *, prompt: str) -> bool:
    """Run a single iteration of the selected AI tool. Return True if complete."""
    if tool == "amp":
        cmd = ["amp", "--dangerously-allow-all"]
    elif tool == "claude":
        cmd = ["claude", "--dangerously-skip-permissions", "--print"]
    elif tool == "opencode":
        cmd = ["opencode", "run"]
    else:
        msg = f"unknown tool: {tool}"
        raise AssertionError(msg)

    input_data = PROMPT_TEMPLATE.format(prompt=prompt)
    stdout, stderr = stream_command(cmd, input_data)
    output = stdout + stderr
    return "<promise>COMPLETE</promise>" in output


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Ralph Wiggum - Long-running AI agent loop",
    )
    parser.add_argument("--tool", choices=["amp", "claude", "opencode"], default="amp")
    parser.add_argument("prompt")
    parser.add_argument("-n", "--max-iterations", type=int, default=10)
    return parser.parse_args()


def main() -> None:
    """Run the agent loop until completion or max iterations."""
    args = parse_args()

    for i in range(1, args.max_iterations + 1):
        print_message(SEPARATOR)
        print_message(f"iteration {i}/{args.max_iterations} [{args.tool}]")
        print_message(SEPARATOR)

        complete = run_iteration(args.tool, prompt=args.prompt)

        if complete:
            print_message(f"complete at iteration {i}/{args.max_iterations}")
            sys.exit(0)

        time.sleep(2)

    print_message(f"max iterations reached ({args.max_iterations})")
    sys.exit(1)


if __name__ == "__main__":
    main()
