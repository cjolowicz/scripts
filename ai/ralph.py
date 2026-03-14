#!/usr/bin/env python3
"""Ralph Wiggum - Long-running AI agent loop."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
import time
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import io
    from collections.abc import Iterable


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
COMPLETION_MARKER = "<promise>COMPLETE</promise>"
CLAUDE_CMD = [
    "claude",
    "--dangerously-skip-permissions",
    "--print",
    "--output-format",
    "stream-json",
    "--verbose",
]


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


def abbreviate(value: object, *, maxlen: int = 80) -> str:
    """Return a single-line repr of value, abbreviated if needed."""
    text = repr(value)
    if len(text) > maxlen:
        return text[: maxlen - 3] + "..."
    return text


TOOL_SUMMARY_KEYS: dict[str, str] = {
    "Bash": "command",
    "Read": "file_path",
    "Edit": "file_path",
    "Write": "file_path",
    "Glob": "pattern",
    "Grep": "pattern",
    "Agent": "prompt",
}


def format_tool_call(name: str, tool_input: dict[str, object]) -> str:
    """Format a tool invocation as a one-liner like Name(summary)."""
    key = TOOL_SUMMARY_KEYS.get(name)
    if key is not None and key in tool_input:
        return f"{name}({abbreviate(tool_input[key])})"
    if tool_input:
        first_value = next(iter(tool_input.values()))
        return f"{name}({abbreviate(first_value)})"
    return f"{name}()"


def handle_text_block(text: str, *, after_tools: bool) -> None:
    """Display a text block, adding a blank line separator after tool blocks."""
    if after_tools:
        sys.stderr.write("\n")
    sys.stdout.write(text + "\n")
    sys.stdout.flush()


def handle_tool_block(
    name: str,
    tool_input: dict[str, object],
    *,
    after_text: bool,
) -> None:
    """Display a tool invocation block."""
    prefix = "\n" if after_text else ""
    sys.stderr.write(f"{prefix}  {format_tool_call(name, tool_input)}\n")
    sys.stderr.flush()


def handle_event(
    event: dict[str, object],
    *,
    last_block: str,
) -> tuple[str | None, str]:
    """Handle a single stream-json event. Return (result, last_block_type)."""
    match event:
        case {"type": "assistant", "message": {"content": list(blocks)}}:
            for block in blocks:
                match block:
                    case {"type": "text", "text": str(text)}:
                        handle_text_block(text, after_tools=last_block == "tool")
                        last_block = "text"
                    case {
                        "type": "tool_use",
                        "name": str(name),
                        "input": dict(tool_input),
                    }:
                        handle_tool_block(
                            name, tool_input, after_text=last_block == "text",
                        )
                        last_block = "tool"
        case {"type": "result", "result": str(result)}:
            return result, last_block
    return None, last_block


def handle_events(lines: Iterable[str]) -> str:
    """Parse and handle stream-json events, returning the final result text."""
    result_text = ""
    last_block = ""
    for line in lines:
        line = line.strip()  # noqa: PLW2901
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        result, last_block = handle_event(event, last_block=last_block)
        if result is not None:
            result_text = result

    return result_text


def stream_claude(input_data: str) -> str:
    """Run claude with stream-json, display events, and return output text."""
    proc = subprocess.Popen(  # noqa: S603
        CLAUDE_CMD,
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

    stderr_lines: list[str] = []
    stderr_thread = threading.Thread(
        target=forward_lines,
        args=(proc.stderr, sys.stderr, stderr_lines),
    )
    stderr_thread.start()

    result_text = handle_events(proc.stdout)

    stderr_thread.join()
    proc.wait()
    return result_text


def run_iteration(prompt: str) -> bool:
    """Run a single iteration of claude. Return True if complete."""
    input_data = PROMPT_TEMPLATE.format(prompt=prompt)
    output = stream_claude(input_data)
    return COMPLETION_MARKER in output


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Ralph Wiggum - Long-running AI agent loop",
    )
    parser.add_argument("prompt")
    parser.add_argument("-n", "--max-iterations", type=int, default=10)
    return parser.parse_args()


def main() -> None:
    """Run the agent loop until completion or max iterations."""
    args = parse_args()

    for i in range(1, args.max_iterations + 1):
        print_message(SEPARATOR)
        print_message(f"iteration {i}/{args.max_iterations}")
        print_message(SEPARATOR)

        complete = run_iteration(args.prompt)

        if complete:
            print_message(f"complete at iteration {i}/{args.max_iterations}")
            sys.exit(0)

        time.sleep(2)

    print_message(f"max iterations reached ({args.max_iterations})")
    sys.exit(1)


if __name__ == "__main__":
    main()
