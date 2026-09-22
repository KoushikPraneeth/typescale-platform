#!/usr/bin/env python3
"""Update the immutable TypeScale image reference in GitOps values."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

TAG_PATTERN = re.compile(r"^[0-9a-f]{40}$")
DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")


def replace_once(text: str, pattern: str, replacement: str) -> str:
    compiled = re.compile(pattern, flags=re.MULTILINE)
    matches = list(compiled.finditer(text))
    if len(matches) != 1:
        raise ValueError(
            f"expected exactly one match for {pattern!r}, found {len(matches)}"
        )
    return compiled.sub(replacement, text, count=1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--digest", required=True)
    args = parser.parse_args()

    if not TAG_PATTERN.fullmatch(args.tag):
        raise ValueError("tag must be a full 40-character Git commit SHA")
    if not DIGEST_PATTERN.fullmatch(args.digest):
        raise ValueError("digest must be a sha256 digest")

    original = args.file.read_text(encoding="utf-8")
    updated = replace_once(
        original,
        r"^(\s{4}tag:)\s+[0-9a-f]{40}$",
        rf"\1 {args.tag}",
    )
    updated = replace_once(
        updated,
        r"^(\s{4}digest:)\s+sha256:[0-9a-f]{64}$",
        rf"\1 {args.digest}",
    )
    args.file.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
