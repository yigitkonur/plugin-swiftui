#!/usr/bin/env python3
"""Stage 1 — Gate candidates via the GitHub API (deterministic, no agents).
For each candidate: fetch repo metadata + languages, apply exclusion rules, record decision.
Outputs: data/01_repos_meta.jsonl (all candidates + decision), data/01_included.json (keep set).
Resumable: skips candidates already present in the meta JSONL.
"""
import json, os, subprocess, time, sys, datetime

CAND = "data/00_candidates.json"
META = "data/01_repos_meta.jsonl"
INCL = "data/01_included.json"
CUTOFF = "2024-06-07"          # 2 years before today (2026-06-07)

def gh_api(path):
    """Return (ok, json_or_none, http_status). Follows renames; handles 404."""
    r = subprocess.run(["gh","api","-i",path], capture_output=True, text=True)
    out = r.stdout
    # parse status line
    status = 0
    if out.startswith("HTTP/"):
        try: status = int(out.split("\n",1)[0].split()[1])
        except: status = 0
    # body = after first blank line
    body = out.split("\r\n\r\n",1)[-1] if "\r\n\r\n" in out else out.split("\n\n",1)[-1]
    if r.returncode != 0 and status == 0:
        # gh prints errors to stderr; detect 404
        if "404" in r.stderr: status = 404
    try:
        data = json.loads(body) if body.strip().startswith(("{","[")) else None
    except Exception:
        data = None
    return (status == 200 and data is not None), data, status

def already_done():
    done = set()
    if os.path.exists(META):
        for ln in open(META):
            try:
                d = json.loads(ln); done.add((d["owner"].lower(), d["repo"].lower()))
            except: pass
    return done

def main():
    cands = json.load(open(CAND))
    done = already_done()
    fmeta = open(META, "a")
    n_incl = 0
    for i, c in enumerate(cands, 1):
        key = (c["owner"].lower(), c["repo"].lower())
        if key in done:
            continue
        owner, repo = c["owner"], c["repo"]
        rec = {"owner": owner, "repo": repo, "url": c["url"], "categories": c["categories"]}
        ok, data, status = gh_api(f"repos/{owner}/{repo}")
        time.sleep(0.08)
        if not ok:
            rec.update(included=False, reason="dead_or_renamed", http=status)
            fmeta.write(json.dumps(rec)+"\n"); fmeta.flush(); continue
        full = data.get("full_name", f"{owner}/{repo}")
        rec["full_name"] = full
        # languages
        lok, langs, _ = gh_api(f"repos/{full}/languages")
        time.sleep(0.08)
        langs = langs if (lok and isinstance(langs, dict)) else {}
        swift_bytes = int(langs.get("Swift", 0))
        total_bytes = sum(int(v) for v in langs.values()) or 1
        pushed = (data.get("pushed_at") or "")[:10]
        rec.update(
            default_branch=data.get("default_branch","main"),
            pushed_at=pushed, created_at=(data.get("created_at") or "")[:10],
            archived=bool(data.get("archived")), disabled=bool(data.get("disabled")),
            fork=bool(data.get("fork")), size_kb=data.get("size",0),
            stars=data.get("stargazers_count",0),
            license=(data.get("license") or {}).get("spdx_id"),
            languages=langs, swift_bytes=swift_bytes,
            swift_share=round(swift_bytes/total_bytes, 4),
            flags=[f for f,on in (("archived",data.get("archived")),
                                  ("fork",data.get("fork"))) if on],
        )
        # exclusion rules (ordered)
        if data.get("disabled"):
            rec.update(included=False, reason="disabled")
        elif pushed and pushed < CUTOFF:
            rec.update(included=False, reason="stale")
        elif swift_bytes < 3000 or rec["swift_share"] < 0.2:
            # incidental Swift (stray .swift file in a JS/C++/Obj-C project) or near-empty stub
            rec.update(included=False, reason="not_swift")
        else:
            rec.update(included=True, reason="ok"); n_incl += 1
        fmeta.write(json.dumps(rec)+"\n"); fmeta.flush()
        if i % 50 == 0:
            print(f"  {i}/{len(cands)} processed", flush=True)
    fmeta.close()
    # build included.json from full meta
    incl = []
    for ln in open(META):
        d = json.loads(ln)
        if d.get("included"):
            incl.append({k: d[k] for k in ("owner","repo","full_name","default_branch",
                         "stars","pushed_at","swift_bytes","swift_share","languages",
                         "categories","flags","license")})
    incl.sort(key=lambda x: -x["stars"])
    json.dump(incl, open(INCL,"w"), indent=2)
    # summary by reason
    from collections import Counter
    reasons = Counter(json.loads(ln)["reason"] for ln in open(META))
    print(f"\nDONE. included={len(incl)}  reasons={dict(reasons)}")

if __name__ == "__main__":
    main()
