#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["rich"]
# ///
"""Ralph Wiggum - Long-running AI agent loop."""

from __future__ import annotations

import argparse
import difflib
import functools
import json
import subprocess
import sys
import time
from pathlib import Path, PurePosixPath
from typing import TYPE_CHECKING

from rich.console import Console  # type: ignore[import-untyped]
from rich.markdown import Markdown  # type: ignore[import-untyped]
from rich.panel import Panel  # type: ignore[import-untyped]
from rich.syntax import Syntax  # type: ignore[import-untyped]
from rich.text import Text  # type: ignore[import-untyped]

if TYPE_CHECKING:
    from collections.abc import Iterable


SEPARATOR = "─" * 63
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
RESET = "\033[0m"
PROMPT_TEMPLATE = """\
<user-prompt>
{prompt}
</user-prompt>

<signals>
You MUST use exactly one of these signals when appropriate:

<signal name="DONE">
Output <signal>DONE</signal> immediately at the START of an invocation if there
is truly nothing left to do. Do NOT output this signal at the end of an
invocation. This ensures that a fresh invocation with a fresh context window
confirms completion.
</signal>

<signal name="BLOCKED">
Output <signal>BLOCKED</signal> if you need user input, clarification, or a
decision before you can continue. Describe what you need, then output the
signal. The loop will stop so the user can intervene.
</signal>
</signals>
"""
SIGNAL_DONE = "<signal>DONE</signal>"
SIGNAL_BLOCKED = "<signal>BLOCKED</signal>"
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
    print(  # noqa: T201
        f"\n{DIM}{SEPARATOR}{RESET}\n{text}\n{DIM}{SEPARATOR}{RESET}\n",
        file=sys.stderr,
    )


def shorten_path(value: str) -> str:
    """Return a path relative to cwd if it's under cwd, otherwise as-is."""
    try:
        return str(Path(value).relative_to(Path.cwd()))
    except ValueError:
        return value


@functools.cache
def git_info() -> tuple[str, str] | None:
    """Return (remote_url_base, commit_hash) or None if not in a git repo."""
    try:
        commit = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        remote = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    else:
        if remote.startswith("git@"):
            remote = remote.replace(":", "/", 1).replace("git@", "https://", 1)
        remote = remote.removesuffix(".git")
        return remote, commit


def github_permalink(
    file_path: str, offset: int | None, limit: int | None
) -> str | None:
    """Return a GitHub permalink for the given file and line range."""
    info = git_info()
    if info is None:
        return None
    remote, commit = info
    path = shorten_path(file_path)
    url = f"{remote}/blob/{commit}/{path}"
    if offset is not None:
        end = offset + (limit or 1) - 1
        url += f"#L{offset}-L{end}"
    return url


def abbreviate(value: object, *, maxlen: int = 72) -> str:
    """Return a single-line repr of value, abbreviated if needed."""
    if isinstance(value, str) and value.startswith("/"):
        value = shorten_path(value)
    text = repr(value)
    if len(text) > maxlen:
        return text[: maxlen - 3] + "..."
    return text


def _format_read(tool_input: dict[str, object]) -> str:
    """Format a Read tool call with path:range and GitHub permalink."""
    path = shorten_path(str(tool_input.get("file_path", "")))
    offset = tool_input.get("offset")
    limit = tool_input.get("limit")
    if isinstance(offset, int) and isinstance(limit, int):
        path += f":{offset}-{offset + limit - 1}"
    elif isinstance(offset, int):
        path += f":{offset}"
    parts = [repr(path)]
    link = github_permalink(
        str(tool_input.get("file_path", "")),
        offset if isinstance(offset, int) else None,
        limit if isinstance(limit, int) else None,
    )
    if link:
        parts.append(f"\n    {DIM}{link}{RESET}")
    return f"Read({''.join(parts)})"


def _format_search(name: str, tool_input: dict[str, object]) -> str:
    """Format a Grep or Glob tool call with pattern and extra filters."""
    parts = [abbreviate(tool_input.get("pattern", ""))]
    if "path" in tool_input:
        parts.append(f"path={abbreviate(tool_input['path'])}")
    if "glob" in tool_input:
        parts.append(f"glob={abbreviate(tool_input['glob'])}")
    return f"{name}({', '.join(parts)})"


def format_tool_call(name: str, tool_input: dict[str, object]) -> str:
    """Format a tool invocation as a one-liner like Name(summary)."""
    match name:
        case "Read":
            return _format_read(tool_input)
        case "Grep" | "Glob":
            return _format_search(name, tool_input)
        case _:
            first_value = next(iter(tool_input.values()), None)
            if first_value is not None:
                return f"{name}({abbreviate(first_value)})"
            return f"{name}()"


def render_markdown(text: str) -> None:
    """Render markdown text to the terminal using rich."""
    Console().print(Markdown(text))


def render_text_block(text: str, *, after_tools: bool) -> None:
    """Display a text block, adding a blank line separator after tool blocks."""
    if after_tools:
        sys.stderr.write("\n")
    render_markdown(text)


def render_edit(file_path: str, old_string: str, new_string: str) -> None:
    """Render an edit as a syntax-highlighted unified diff."""
    path = shorten_path(file_path)
    old_lines = (old_string + "\n").splitlines(keepends=True)
    new_lines = (new_string + "\n").splitlines(keepends=True)
    diff_lines = difflib.unified_diff(
        old_lines,
        new_lines,
        fromfile=f"a/{path}",
        tofile=f"b/{path}",
    )
    diff_text = "".join(diff_lines)
    if not diff_text:
        return

    stderr = Console(stderr=True)
    stderr.print()
    stderr.print(
        Panel(
            Syntax(diff_text, "diff", theme="ansi_dark"),
            title="Edit",
            subtitle=path,
            border_style="dim",
            expand=False,
        )
    )


def render_write(file_path: str, content: str) -> None:
    """Render a Write invocation with syntax-highlighted content."""
    path = shorten_path(file_path)
    suffix = PurePosixPath(path).suffix.lstrip(".")
    lexer = suffix or "text"

    stderr = Console(stderr=True)
    stderr.print()
    stderr.print(
        Panel(
            Syntax(content, lexer, theme="ansi_dark"),
            title="Write",
            subtitle=path,
            border_style="dim",
            expand=False,
        ),
    )


def render_skill(skill_input: dict[str, object]) -> None:
    """Render a Skill invocation with skill name and args."""
    skill = str(skill_input.get("skill", ""))
    args = skill_input.get("args")
    lines = [f"[bold]{skill}[/bold]"]
    if args:
        lines.append(f"[dim]{args}[/dim]")

    stderr = Console(stderr=True)
    stderr.print()
    stderr.print(
        Panel(
            "\n".join(lines),
            title="Skill",
            border_style="dim",
            expand=False,
        ),
    )


def render_tool_block(
    name: str,
    tool_input: dict[str, object],
    *,
    after_text: bool,
) -> None:
    """Display a tool invocation block."""
    prefix = "\n" if after_text else ""
    sys.stderr.write(f"{prefix}  {DIM}{format_tool_call(name, tool_input)}{RESET}\n")
    sys.stderr.flush()


STATUS_STYLES: dict[str, tuple[str, str]] = {
    "completed": ("✓", "green"),
    "in_progress": ("●", "yellow"),
    "pending": ("○", "dim"),
}


def render_todos(todos: list[dict[str, str]]) -> None:
    """Render a todo list as a styled checklist."""
    if not todos:
        return
    text = Text()
    for i, todo in enumerate(todos):
        status = todo.get("status", "pending")
        icon, style = STATUS_STYLES.get(status, ("?", ""))
        content = todo.get("content", "")
        if i > 0:
            text.append("\n")
        text.append(f"{icon} ", style=style)
        text.append(content)

    stderr = Console(stderr=True)
    stderr.print()
    stderr.print(Panel(text, title="TodoWrite", border_style="dim", expand=False))


def render_agent(agent_input: dict[str, object]) -> None:
    """Render an Agent invocation with prompt and metadata."""
    prompt = agent_input.get("prompt", "")
    subtitle_parts = []
    if "description" in agent_input:
        subtitle_parts.append(str(agent_input["description"]))
    if "subagent_type" in agent_input:
        subtitle_parts.append(str(agent_input["subagent_type"]))
    subtitle = " · ".join(subtitle_parts) or None

    stderr = Console(stderr=True)
    stderr.print()
    stderr.print(
        Panel(
            str(prompt),
            title="Agent",
            subtitle=subtitle,
            border_style="dim",
            expand=False,
        ),
    )


def render_bash(command: str, output: str, duration: str) -> None:
    """Render a Bash invocation with command, output, and timing."""
    stderr = Console(stderr=True)
    stderr.print()
    lines = [f"[dim]$ {command}[/dim]"]
    if output.strip():
        lines.append(output.rstrip())
    if duration:
        lines.append(f"[dim]({duration})[/dim]")
    stderr.print(
        Panel(
            "\n".join(lines),
            title="Bash",
            border_style="dim",
            expand=False,
        ),
    )


class EventRenderer:
    """Stateful renderer for stream-json events."""

    def __init__(self) -> None:
        """Initialize renderer state."""
        self.last_block = ""
        self.pending_bash: dict[str, str] = {}

    def render(self, event: dict[str, object]) -> str | None:
        """Render a single event. Return result text if final."""
        match event:
            case {"type": "assistant", "message": {"content": list(blocks)}}:
                self._render_blocks(blocks)
            case {
                "type": "user",
                "message": {
                    "content": [
                        {
                            "tool_use_id": str(tool_id),
                            "type": "tool_result",
                            "content": str(output),
                        },
                    ],
                },
            } if tool_id in self.pending_bash:
                command = self.pending_bash.pop(tool_id)
                duration = ""
                match event:
                    case {
                        "tool_use_result": {"duration_ms": int(ms)},
                    }:
                        duration = f"{ms / 1000:.1f}s"
                    case _:
                        pass
                render_bash(command, output, duration)
                self.last_block = "tool"
            case {
                "type": "user",
                "tool_use_result": {"newTodos": list(todos)},
            }:
                render_todos(todos)
                self.last_block = "tool"
            case {"type": "result", "result": str(result)}:
                return result
        return None

    def _render_blocks(self, blocks: list[object]) -> None:
        """Render content blocks from an assistant message."""
        for block in blocks:
            match block:
                case {"type": "text", "text": str(text)}:
                    render_text_block(
                        text,
                        after_tools=self.last_block == "tool",
                    )
                    self.last_block = "text"
                case {
                    "type": "tool_use",
                    "name": "Edit",
                    "input": {
                        "file_path": str(fp),
                        "old_string": str(old),
                        "new_string": str(new),
                    },
                }:
                    render_edit(fp, old, new)
                    self.last_block = "tool"
                case {
                    "type": "tool_use",
                    "name": "Write",
                    "input": {
                        "file_path": str(fp),
                        "content": str(content),
                    },
                }:
                    render_write(fp, content)
                    self.last_block = "tool"
                case {
                    "type": "tool_use",
                    "id": str(tool_id),
                    "name": "Bash",
                    "input": {"command": str(command)},
                }:
                    self.pending_bash[tool_id] = command
                    self.last_block = "tool"
                case {
                    "type": "tool_use",
                    "name": "Agent",
                    "input": dict(agent_input),
                }:
                    render_agent(agent_input)
                    self.last_block = "tool"
                case {
                    "type": "tool_use",
                    "name": "Skill",
                    "input": dict(skill_input),
                }:
                    render_skill(skill_input)
                    self.last_block = "tool"
                case {
                    "type": "tool_use",
                    "name": "TodoWrite",
                }:
                    self.last_block = "tool"
                case {
                    "type": "tool_use",
                    "name": str(name),
                    "input": dict(tool_input),
                }:
                    render_tool_block(
                        name,
                        tool_input,
                        after_text=self.last_block == "text",
                    )
                    self.last_block = "tool"


def render_events(lines: Iterable[str]) -> str:
    """Parse and render stream-json events, returning the final result text."""
    renderer = EventRenderer()
    result_text = ""
    for line in lines:
        line = line.strip()  # noqa: PLW2901
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        result = renderer.render(event)
        if result is not None:
            result_text = result

    return result_text


def stream_claude(prompt: str) -> str:
    """Run claude with stream-json, display events, and return output text."""
    with subprocess.Popen(
        [*CLAUDE_CMD, prompt],
        stdout=subprocess.PIPE,
        text=True,
    ) as proc:
        assert proc.stdout is not None  # noqa: S101
        return render_events(proc.stdout)


def run_iteration(prompt: str) -> str:
    """Run a single iteration of claude. Return 'done', 'blocked', or 'continue'."""
    full_prompt = PROMPT_TEMPLATE.format(prompt=prompt)
    output = stream_claude(full_prompt)
    if SIGNAL_DONE in output:
        return "done"
    if SIGNAL_BLOCKED in output:
        return "blocked"
    return "continue"


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt")
    parser.add_argument("-n", "--max-iterations", type=int, default=10)
    return parser.parse_args()


def main() -> None:
    """Run the agent loop until completion or max iterations."""
    args = parse_args()

    for i in range(1, args.max_iterations + 1):
        print_message(f"{BOLD}iteration {i}/{args.max_iterations}{RESET}")

        status = run_iteration(args.prompt)

        if status == "done":
            print_message(f"{GREEN}done at iteration {i}/{args.max_iterations}{RESET}")
            sys.exit(0)

        if status == "blocked":
            n = args.max_iterations
            print_message(f"{YELLOW}blocked at iteration {i}/{n}{RESET}")
            sys.exit(1)

        time.sleep(2)

    print_message(f"{RED}max iterations reached ({args.max_iterations}){RESET}")
    sys.exit(2)


if __name__ == "__main__":
    main()
