#!/bin/sh
# Keep non-manifest version consumers in step with the kit's release decision.
set -eu
python3 - "$1" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path.cwd()
version = sys.argv[1]
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit("expected x.y.z")
for rel in ("VERSION", "plugins/swiftui/VERSION"):
    (root / rel).write_text(version + "\n")
packages = ("package.json", "packages/claude-plugin/package.json", "packages/codex-plugin/package.json",
            "packages/swiftui-core/package.json", "plugins/swiftui/package.json")
for rel in packages:
    path = root / rel
    data = json.loads(path.read_text())
    data["version"] = version
    path.write_text(json.dumps(data, indent=2) + "\n")
path = root / "package-lock.json"
data = json.loads(path.read_text())
data["version"] = version
for key in ("", "packages/claude-plugin", "packages/codex-plugin", "packages/swiftui-core"):
    data["packages"][key]["version"] = version
path.write_text(json.dumps(data, indent=2) + "\n")
for rel in ("swiftui-scan/Sources/swiftui-ctx/SwiftUICtx.swift",
            "plugins/swiftui/swiftui-scan/Sources/swiftui-ctx/SwiftUICtx.swift"):
    path = root / rel
    text, count = re.subn(r'(?m)^let swiftuiCtxVersion = "[^"\n]+"$',
                          'let swiftuiCtxVersion = "' + version + '"', path.read_text())
    if count != 1:
        raise SystemExit("expected one swiftuiCtxVersion in " + rel)
    path.write_text(text)
path = root / "README.md"
text, count = re.subn(r'badge/version-\d+\.\d+\.\d+-blue', 'badge/version-' + version + '-blue', path.read_text())
if count != 1:
    raise SystemExit("expected one README version badge")
path.write_text(text)
# The committed self-contained Codex bundle embeds this build-time constant.
path = root / "plugins/swiftui/mcp/server.mjs"
text, count = re.subn(r'(name: "swiftui-production-intelligence", version: ")[^"]+(" \})',
                      lambda m: m[1] + version + m[2], path.read_text())
if count != 1:
    raise SystemExit("expected one bundled MCP server version")
path.write_text(text)
PY
