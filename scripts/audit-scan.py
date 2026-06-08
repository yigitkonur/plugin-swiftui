#!/usr/bin/env python3
"""audit-scan.py — relevance STEERING for the macOS-SwiftUI audit orchestrator.

Scans a target project and reports WHICH audit-swiftui-* skills are relevant (their domain is
actually present), each scoped to the files where its signal hits — so the orchestrator
(audit-macos-swiftui-full) dispatches subagent waves over only the relevant set instead of blindly
running all 28. The 8 `always` skills are cross-cutting (run on any SwiftUI project); the 20 `cond`
skills fire only when their presence signal (scripts/audit-signals.tsv) matches.

Usage:
    python3 audit-scan.py <project-dir> [--json out.json]
Output (stdout or --json): {project, swiftui_files, relevant_skills[], skipped_skills[], detail[]}
Exit: 0 ok · 64 bad args/no signals · (always emits valid JSON when it can).
"""
import os
import re
import sys
import json

HERE = os.path.dirname(os.path.abspath(__file__))
SIGNALS = os.path.join(HERE, "audit-signals.tsv")
PRUNE = {".build", ".git", "DerivedData", "Pods", "Carthage", "node_modules", ".swiftpm"}


def main():
    args = sys.argv[1:]
    target = next((a for a in args if not a.startswith("-")), ".")
    out = None
    if "--json" in args:
        i = args.index("--json")
        if i + 1 < len(args):
            out = args[i + 1]

    if not os.path.exists(target):
        sys.stderr.write(f"audit-scan: target not found: {target}\n")
        sys.exit(64)
    if not os.path.isfile(SIGNALS):
        sys.stderr.write(f"audit-scan: signals not found: {SIGNALS}\n")
        sys.exit(64)

    # 1. collect every .swift file that imports SwiftUI (the audit surface)
    swift = []  # (relpath, text)
    for root, dirs, files in os.walk(target):
        dirs[:] = [d for d in dirs if d not in PRUNE]
        for fn in files:
            if not fn.endswith(".swift"):
                continue
            p = os.path.join(root, fn)
            try:
                txt = open(p, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            if "import SwiftUI" in txt or "import SwiftUICore" in txt:
                swift.append((os.path.relpath(p, target), txt))

    # 2. load the signal map
    signals = []
    for line in open(SIGNALS, encoding="utf-8", errors="ignore"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        signals.append((parts[0].strip(), parts[1].strip(), parts[2]))

    # 3. decide relevance
    relevant, skipped = [], []
    for skill, mode, pattern in signals:
        full = "audit-swiftui-" + skill
        if mode == "always":
            if swift:
                relevant.append({"skill": full, "mode": "always",
                                 "file_count": len(swift),
                                 "files": [p for p, _ in swift][:80]})
            else:
                skipped.append(full)
            continue
        try:
            rx = re.compile(pattern)
        except re.error:
            rx = None
        hits = [p for p, txt in swift if rx and rx.search(txt)]
        if hits:
            relevant.append({"skill": full, "mode": "cond",
                             "file_count": len(hits), "files": hits[:80]})
        else:
            skipped.append(full)

    result = {
        "tool": "audit-scan",
        "role": "relevance-steering",
        "note": "Dispatch audit subagents over relevant_skills only, each scoped to its detail.files. "
                "always = cross-cutting (any SwiftUI); cond = domain present in the listed files.",
        "project": os.path.abspath(target),
        "swiftui_files": len(swift),
        "relevant_skills": [r["skill"] for r in relevant],
        "skipped_skills": skipped,
        "detail": relevant,
    }
    payload = json.dumps(result, indent=2)
    if out and out != "-":
        open(out, "w", encoding="utf-8").write(payload + "\n")
    else:
        print(payload)
    sys.stderr.write(
        f"audit-scan: {len(swift)} SwiftUI file(s) · {len(relevant)} relevant · {len(skipped)} skipped\n")


if __name__ == "__main__":
    main()
