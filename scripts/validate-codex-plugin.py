#!/usr/bin/env python3
"""Dependency-light validation for the assembled Codex plugin used in CI and local checks."""

import json
import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"validate-codex-plugin: {message}")


root = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/codex-swiftui-plugin").resolve()
manifest_path = root / ".codex-plugin" / "plugin.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    fail(f"invalid manifest: {error}")

for key in ("name", "version", "description", "author", "interface"):
    if not manifest.get(key):
        fail(f"manifest missing {key}")
if not re.fullmatch(r"\d+\.\d+\.\d+", manifest["version"]):
    fail("manifest version is not strict semver")
for relative in (manifest.get("skills"), manifest.get("mcpServers")):
    if not relative or not relative.startswith("./") or not (root / relative[2:]).exists():
        fail(f"invalid component path: {relative}")
if "hooks" in manifest:
    fail("manifest must rely on default hooks/hooks.json discovery")

skills = sorted((root / "skills").glob("*/SKILL.md"))
if len(skills) != 37:
    fail(f"expected 37 skills, found {len(skills)}")
for skill in skills:
    text = skill.read_text(encoding="utf-8")
    frontmatter = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not frontmatter:
        fail(f"missing frontmatter: {skill}")
    name = re.search(r"^name:\s*(.+)$", frontmatter.group(1), re.M)
    description = re.search(r"^description:\s*(.+)$", frontmatter.group(1), re.M)
    if not name or name.group(1).strip() != skill.parent.name or not description:
        fail(f"invalid name or description: {skill}")
    if "CLAUDE_PLUGIN_ROOT" in text:
        fail(f"unresolved Claude root in {skill}")

print(f"validate-codex-plugin: {len(skills)} skills + manifest OK")
