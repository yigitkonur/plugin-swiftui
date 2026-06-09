#!/usr/bin/env python3
"""Stage 6 — Discover NEW macOS SwiftUI apps via GitHub code search.

Runs a set of macOS-EXCLUSIVE SwiftUI symbols (APIs that do not exist on iOS, so a Swift file
containing them is almost certainly a macOS SwiftUI app) through `gh search code`, aggregates the
unique owner/repo across terms, records term provenance, and dedupes against the known corpus.

Writes data/06_discovered.jsonl — one JSON object per discovered repo:
  {full_name, owner, repo, found_by:[terms], match_files, in_awesome_mac, in_corpus_207, discovered_via}

Reusable downstream: feed the NEW repos into scripts/01_gate.py-style gating + scanning.

Rate-limit aware: GitHub code search = 10 req/min; we throttle between terms and back off on 403.
Resumable: re-running merges with any existing data/06_discovered.jsonl.
"""
import json, os, subprocess, time, sys, argparse

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, "..")
OUT  = os.path.join(ROOT, "data", "06_discovered.jsonl")
CAND = os.path.join(ROOT, "data", "00_candidates.json")
INCL = os.path.join(ROOT, "data", "01_included.json")

# macOS-EXCLUSIVE SwiftUI discriminators (data-derived from the SDK availability graph:
# introduced on macOS, never on iOS) — restricted to distinctive tokens that code-search cleanly.
# Generic words (Settings/Window/Table) are intentionally omitted: too noisy as bare tokens.
TERMS = [
    # Tier A — broad, high-signal
    "MenuBarExtra", "menuBarExtraStyle", "windowResizability", "windowStyle",
    "windowToolbarStyle", "NSApplicationDelegateAdaptor", "onExitCommand",
    # Tier B — distinctive / niche (surface apps the broad terms miss)
    "HiddenTitleBarWindowStyle", "SettingsLink", "alternatingRowBackgrounds",
    "horizontalRadioGroupLayout", "RadioGroupPickerStyle", "defaultLaunchBehavior",
    "WindowDragGesture", "UtilityWindow", "windowMinimizeBehavior", "windowLevel",
    "onModifierKeysChanged", "pointerStyle", "focusSection", "CheckboxToggleStyle",
    # Tier C — AppKit↔SwiftUI bridges (macOS-guaranteed)
    "NSHostingController", "NSViewControllerRepresentable",
]

def known_sets():
    import glob
    awesome, corpus, scanned = set(), set(), set()
    if os.path.exists(CAND):
        for c in json.load(open(CAND)): awesome.add(f"{c['owner']}/{c['repo']}".lower())
    if os.path.exists(INCL):
        for c in json.load(open(INCL)): corpus.add(c.get("full_name","").lower())
    # everything already scanned into repos/ (awesome-mac + any prior discovery wave)
    for f in glob.glob(os.path.join(ROOT,"repos","*.jsonl")):
        try:
            h = json.loads(open(f).readline())
            if h.get("full_name"): scanned.add(h["full_name"].lower())
        except Exception: pass
    return awesome, corpus, scanned

def search(term, limit):
    """Return list of nameWithOwner for a term, retrying on secondary-rate-limit."""
    for attempt in range(4):
        r = subprocess.run(
            ["gh","search","code", term, "--language","swift","--limit",str(limit),
             "--json","repository","--jq",".[].repository.nameWithOwner"],
            capture_output=True, text=True)
        if r.returncode == 0:
            return [x.strip() for x in r.stdout.splitlines() if x.strip()]
        if "rate limit" in (r.stderr or "").lower() or "403" in (r.stderr or ""):
            wait = 20*(attempt+1); print(f"    rate-limited on '{term}', sleeping {wait}s", flush=True)
            time.sleep(wait); continue
        print(f"    error on '{term}': {r.stderr.strip()[:160]}", flush=True)
        return []
    return []

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=100, help="results per term")
    ap.add_argument("--sleep", type=float, default=7.0, help="seconds between terms (10/min cap)")
    ap.add_argument("--terms", default="", help="comma-separated subset (pilot)")
    ap.add_argument("--out", default=OUT, help="output JSONL path")
    args = ap.parse_args()
    terms = [t.strip() for t in args.terms.split(",") if t.strip()] or TERMS

    awesome, corpus, scanned = known_sets()
    found = {}   # full_name -> {found_by:set, match_files:int}
    for i, term in enumerate(terms, 1):
        hits = search(term, args.limit)
        repos = {}
        for nwo in hits:
            repos[nwo] = repos.get(nwo, 0) + 1
        for nwo, n in repos.items():
            e = found.setdefault(nwo, {"found_by": set(), "match_files": 0})
            e["found_by"].add(term); e["match_files"] += n
        print(f"  [{i}/{len(terms)}] {term:30} hits={len(hits):>3} unique_repos={len(repos)} total_found={len(found)}", flush=True)
        if i < len(terms): time.sleep(args.sleep)

    os.makedirs(os.path.join(ROOT,"data"), exist_ok=True)
    rows = []
    for nwo, e in sorted(found.items()):
        if "/" not in nwo: continue
        owner, repo = nwo.split("/", 1)
        low = nwo.lower()
        rows.append({"full_name": nwo, "owner": owner, "repo": repo,
                     "found_by": sorted(e["found_by"]), "match_files": e["match_files"],
                     "in_awesome_mac": low in awesome, "in_corpus_207": low in corpus,
                     "already_scanned": low in scanned, "is_new": low not in scanned,
                     "discovered_via": "github-code-search"})
    with open(args.out, "w") as f:
        for r in rows: f.write(json.dumps(r) + "\n")
    new = [r for r in rows if r["is_new"]]
    print(f"\nwrote {args.out}: {len(rows)} repos discovered")
    print(f"  already scanned (in current corpus): {len(rows)-len(new)}")
    print(f"  NEW (not yet in corpus):             {len(new)}")
    print("  sample new:", [r["full_name"] for r in new[:10]])

if __name__ == "__main__":
    main()
