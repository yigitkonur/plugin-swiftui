#!/usr/bin/env python3
"""Stage 0 — Harvest GitHub owner/repo candidates from the awesome-mac README,
attaching the markdown section heading(s) each link appeared under as `categories`.
Output: data/00_candidates.json
"""
import re, json, os, sys, urllib.request, pathlib

RAW = "https://raw.githubusercontent.com/jaywcjlove/awesome-mac/master/README.md"
LOCAL = "/tmp/awesome-mac.md"
OUT = "data/00_candidates.json"

RESERVED = {"sponsors","topics","about","features","marketplace","settings","apps",
            "orgs","users","collections","login","notifications","explore","pulls",
            "issues","new","search","trending","stars","watching"}
SELF = ("jaywcjlove","awesome-mac")

LINK = re.compile(r'https?://github\.com/([A-Za-z0-9][\w.-]*)/([A-Za-z0-9][\w.-]*)', re.I)
HEAD = re.compile(r'^(#{1,4})\s+(.*?)\s*#*\s*$')

def clean_repo(repo: str) -> str:
    # strip sub-paths, anchors, queries, trailing punctuation and .git
    repo = repo.split('#')[0].split('?')[0]
    repo = re.sub(r'\.git$', '', repo)
    repo = repo.rstrip(').,;:*"\'`')
    return repo

def load_md() -> str:
    if os.path.exists(LOCAL):
        return pathlib.Path(LOCAL).read_text(errors="ignore")
    data = urllib.request.urlopen(RAW, timeout=30).read().decode("utf-8", "ignore")
    pathlib.Path(LOCAL).write_text(data)
    return data

def main():
    md = load_md()
    cands = {}           # (owner_lc, repo_lc) -> {owner, repo, url, categories:set}
    heading_stack = {}   # level -> text
    for line in md.splitlines():
        hm = HEAD.match(line)
        if hm:
            lvl = len(hm.group(1)); txt = hm.group(2).strip()
            heading_stack[lvl] = txt
            # clear deeper levels
            for d in list(heading_stack):
                if d > lvl: del heading_stack[d]
            continue
        for m in LINK.finditer(line):
            owner = m.group(1); repo = clean_repo(m.group(2))
            if not owner or not repo: continue
            if repo.lower() in RESERVED: continue
            if (owner.lower(), repo.lower()) == (SELF[0], SELF[1]): continue
            # current category = deepest non-top heading (skip the H1 title)
            cats = [heading_stack[d] for d in sorted(heading_stack) if d >= 2]
            cat = cats[-1] if cats else (heading_stack.get(1, "Uncategorized"))
            key = (owner.lower(), repo.lower())
            e = cands.setdefault(key, {"owner": owner, "repo": repo,
                                       "url": f"https://github.com/{owner}/{repo}",
                                       "categories": set()})
            e["categories"].add(cat)
    out = []
    for e in cands.values():
        e["categories"] = sorted(e["categories"])
        out.append(e)
    out.sort(key=lambda x: (x["owner"].lower(), x["repo"].lower()))
    os.makedirs("data", exist_ok=True)
    json.dump(out, open(OUT, "w"), indent=2)
    print(f"harvested {len(out)} unique owner/repo candidates -> {OUT}")
    # quick category histogram
    from collections import Counter
    c = Counter(cat for e in out for cat in e["categories"])
    print("top categories:", c.most_common(8))

if __name__ == "__main__":
    main()
