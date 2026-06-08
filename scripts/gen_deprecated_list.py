#!/usr/bin/env python3
"""Generate hooks/deprecated-names.txt (api|replacement, one per line) from the catalog's
deprecated-in-the-wild list, so the PostToolUse guard can grep edits without a CLI call."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, "..")
ins = json.load(open(os.path.join(ROOT, "catalog", "insights.json")))
out = []
for d in ins.get("deprecated_api_usage", []):
    sym = d.get("sym"); rep = d.get("renamed") or "(no replacement)"
    if sym and sym[:1].isalpha():
        out.append(f"{sym}|{rep}")
path = os.path.join(ROOT, "hooks", "deprecated-names.txt")
open(path, "w").write("\n".join(out) + "\n")
print(f"wrote {len(out)} deprecated names → {path}")
