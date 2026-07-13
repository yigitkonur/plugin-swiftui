#!/usr/bin/env python3
"""Normalize Claude and Codex edit-hook payloads and report added deprecated APIs."""

import json
import re
import sys
from pathlib import Path


def added_patch_text(command: str) -> str:
    snippets = []
    swift_file = False
    for line in command.splitlines():
        if line.startswith(("*** Add File: ", "*** Update File: ", "*** Move to: ")):
            swift_file = line.split(": ", 1)[1].strip().endswith(".swift")
            continue
        if line.startswith("*** "):
            swift_file = False
            continue
        if swift_file and line.startswith("+") and not line.startswith("+++"):
            snippets.append(line[1:])
    return "\n".join(snippets)


def authored_text(value) -> list[str]:
    if isinstance(value, dict):
        found = []
        for key, child in value.items():
            if key in {"content", "new_string", "text"} and isinstance(child, str):
                found.append(child)
            elif key not in {"old_string", "command"}:
                found.extend(authored_text(child))
        return found
    if isinstance(value, list):
        found = []
        for child in value:
            found.extend(authored_text(child))
        return found
    return []


def candidate_text(payload: dict) -> str:
    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return ""

    command = tool_input.get("command")
    if isinstance(command, str) and "*** Begin Patch" in command:
        return added_patch_text(command)

    file_path = tool_input.get("file_path") or tool_input.get("path")
    if not isinstance(file_path, str) or not file_path.endswith(".swift"):
        return ""
    return "\n".join(authored_text(tool_input))


def load_deprecations(path: Path) -> list[tuple[str, str]]:
    entries = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#"):
            continue
        api, replacement = raw.split("|", 1)
        entries.append((api, replacement))
    return entries


def main() -> int:
    if len(sys.argv) != 2:
        return 0
    try:
        payload = json.load(sys.stdin)
        text = candidate_text(payload)
        if not text:
            return 0
        hits = []
        for api, replacement in load_deprecations(Path(sys.argv[1])):
            pattern = rf"(?:[.(]|\b){re.escape(api)}\b"
            if re.search(pattern, text):
                hits.append((api, replacement))
        if not hits:
            return 0
        lines = ["swiftui: this .swift edit may use deprecated SwiftUI APIs:"]
        lines.extend(f"  - .{api} -> {replacement}" for api, replacement in hits)
        lines.append("Verify with `swiftui-ctx deprecated <api>` and migrate (skill: swiftui-modernize).")
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": "\n".join(lines),
            }
        }
        print(json.dumps(output, separators=(",", ":")))
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
