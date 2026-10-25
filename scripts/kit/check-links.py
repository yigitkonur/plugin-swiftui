#!/usr/bin/env python3
"""check-links.py: relative links in the repo's markdown must point at files that exist. Vendored as scripts/kit/check-links.py.

  python3 scripts/kit/check-links.py [--root DIR]

Looks at README.md, AGENTS.md, CHANGELOG.md and every .md under docs/ and the plugin folders' own README/SKILL files that git tracks.
Only [text](relative/path) and ![img](relative/path) are checked, with #anchors and ?queries cut off; http(s), mailto and in-page
anchors are skipped (network checks stay in the weekly freshness workflows). A line holding "nolink" is skipped.
"""
import os
import re
import subprocess
import sys

LINK = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def main(argv):
    root = os.getcwd()
    if "--root" in argv:
        root = os.path.abspath(argv[argv.index("--root") + 1])
    files = subprocess.run(["git", "-C", root, "ls-files", "*.md"], capture_output=True, text=True).stdout.splitlines()
    bad = []
    for f in files:
        if re.search(r"(^|/)(node_modules|fixtures|evals|tests|spikes|sources|_sources)/", f):
            continue
        in_fence = False
        for n, line in enumerate(open(os.path.join(root, f), encoding="utf-8", errors="replace").read().splitlines(), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
            if in_fence or "nolink" in line:
                continue
            for target in LINK.findall(re.sub(r"`[^`]*`", "", line)):   # inline code is not a link
                if re.match(r"^(https?:|mailto:|#|tel:|data:)", target):
                    continue
                path = target.split("#")[0].split("?")[0]
                if not path:
                    continue
                full = os.path.normpath(os.path.join(root, path.lstrip("/")) if path.startswith("/") else os.path.join(root, os.path.dirname(f), path))
                if not os.path.exists(full):
                    bad.append("%s:%d: link to missing file %s" % (f, n, target))
    for b in bad:
        print("FAIL  " + b)
    print("check-links: %s" % ("OK (%d markdown files)" % len(files) if not bad else "%d broken link(s)" % len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
