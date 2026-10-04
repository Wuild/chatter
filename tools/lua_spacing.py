#!/usr/bin/env python3
"""Separate Lua functions and closing blocks without changing strings, comments, or code."""

import argparse
import bisect
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
LONG_OPEN = re.compile(r"\[(=*)\[")
TOKEN = re.compile(r"[A-Za-z_][A-Za-z_0-9]*|\S")


def tokens(source):
    """Skip Lua comments and string literals, including long bracket literals."""
    position = 0
    while position < len(source):
        if source[position].isspace():
            position += 1
            continue
        comment = source.startswith("--", position)
        start = position + 2 if comment else position
        long_open = LONG_OPEN.match(source, start)
        if long_open:
            close = "]" + long_open[1] + "]"
            end = source.find(close, long_open.end())
            position = len(source) if end < 0 else end + len(close)
        elif comment:
            end = source.find("\n", start)
            position = len(source) if end < 0 else end
        elif source[position] in "\"'":
            quote = source[position]
            position += 1
            while position < len(source):
                char = source[position]
                position += 1
                if char == "\\":
                    position += 1
                elif char == quote:
                    break
        else:
            match = TOKEN.match(source, position)
            yield match[0], position
            position = match.end()


def format_spacing(source):
    lines = source.splitlines(keepends=True)
    starts = [0]
    for line in lines:
        starts.append(starts[-1] + len(line))
    lexemes = list(tokens(source))
    boundaries = set()
    for index, (token, offset) in enumerate(lexemes):
        line = bisect.bisect_right(starts, offset) - 1
        if token == "function":
            named = index + 1 < len(lexemes) and re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", lexemes[index + 1][0])
            if named:
                # Keep documentation comments attached to the following method.
                while line > 0 and lines[line - 1].lstrip().startswith("--"):
                    line -= 1
                previous = lines[line - 1].strip() if line else ""
                opens_block = (
                    re.match(r"(?:local\s+)?function\b", previous)
                    or previous.endswith((" then", " do"))
                    or previous in {"else", "do", "repeat"}
                )
                if not opens_block:
                    boundaries.add(line)
    # Separate a completed block from the next statement, but keep closing
    # braces/ends and else/elseif/until continuations together. Only inspect
    # code tokens, so text inside strings and comments is never rewritten.
    by_line = {}
    for token, offset in lexemes:
        line = bisect.bisect_right(starts, offset) - 1
        by_line.setdefault(line, []).append(token)
    code_lines = sorted(by_line)
    continuations = {"end", "}", ")", "]", "else", "elseif", "until", ",", ";"}
    closers = {"end", "}", ")", "]", ",", ";"}
    for current, following in zip(code_lines, code_lines[1:]):
        current_tokens = by_line[current]
        if (
            current_tokens[0] in {"end", "}"}
            and all(token in closers for token in current_tokens)
            and by_line[following][0] not in continuations
        ):
            boundaries.add(current + 1)
    output = []
    for index, line in enumerate(lines):
        if index in boundaries and output and output[-1].strip() and line.strip():
            output.append("\n")
        output.append(line)
    return "".join(output)


def source_files():
    for directory in ("scripts", "extensions", "locales", "tests"):
        for path in sorted((ROOT / directory).rglob("*.lua")):
            if not path.is_relative_to(ROOT / "scripts/libraries"):
                yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report missing blank lines without editing")
    args = parser.parse_args()
    changed = 0
    for path in source_files():
        source = path.read_text()
        formatted = format_spacing(source)
        if formatted != source:
            changed += 1
            if args.check:
                print(f"{path.relative_to(ROOT)}: missing blank lines around functions/blocks (run make format)")
            else:
                path.write_text(formatted)
    if args.check and changed:
        return 1
    print(f"Lua spacing: {'checked' if args.check else 'formatted'} ({changed} files changed).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
