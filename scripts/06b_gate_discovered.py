#!/usr/bin/env python3
"""Stage 6b — Gate the code-search-discovered repos (data/06_discovered.jsonl) with the SAME
rules as the awesome-mac corpus (recency ≥2024-06-07, Swift share ≥0.2 & ≥3KB, alive), and write
data/06_included_new.json (the NEW, passing repos, with discovery provenance) ready for the scanner.

Resumable: caches per-repo metadata in data/06_discovered_meta.jsonl.
"""
import json, os, subprocess, time, argparse

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, "..")
_ap = argparse.ArgumentParser()
_ap.add_argument("--disc", default=os.path.join(ROOT,"data","06_discovered.jsonl"))
_ap.add_argument("--meta", default=os.path.join(ROOT,"data","06_discovered_meta.jsonl"))
_ap.add_argument("--out",  default=os.path.join(ROOT,"data","06_included_new.json"))
_A = _ap.parse_args()
DISC, META, OUT = _A.disc, _A.meta, _A.out
CUTOFF = "2024-06-07"

def gh_json(path):
    r = subprocess.run(["gh","api",path], capture_output=True, text=True)
    if r.returncode != 0: return None
    try: return json.loads(r.stdout)
    except: return None

def done_set():
    s = {}
    if os.path.exists(META):
        for ln in open(META):
            try: d=json.loads(ln); s[d["full_name"].lower()]=d
            except: pass
    return s

def main():
    disc = [json.loads(l) for l in open(DISC)]
    # "new" = not already scanned into the corpus (back-compat: fall back to in_corpus_207 flag)
    new = [d for d in disc if d.get("is_new", not d.get("in_corpus_207"))]
    cache = done_set()
    fmeta = open(META, "a")
    print(f"gating {len(new)} discovered repos not already in the 207 corpus")
    for i, d in enumerate(new, 1):
        full = d["full_name"]
        if full.lower() in cache: continue
        data = gh_json(f"repos/{full}"); time.sleep(0.08)
        rec = {"full_name": full, "found_by": d.get("found_by"), "match_files": d.get("match_files")}
        if not data:
            rec.update(included=False, reason="dead_or_renamed")
            fmeta.write(json.dumps(rec)+"\n"); fmeta.flush(); continue
        full2 = data.get("full_name", full)
        langs = gh_json(f"repos/{full2}/languages") or {}; time.sleep(0.08)
        sb = int(langs.get("Swift",0)); tot = sum(int(v) for v in langs.values()) or 1
        pushed = (data.get("pushed_at") or "")[:10]
        rec.update(full_name=full2, owner=full2.split("/")[0], repo=full2.split("/")[1],
                   default_branch=data.get("default_branch","main"), pushed_at=pushed,
                   stars=data.get("stargazers_count",0), archived=bool(data.get("archived")),
                   fork=bool(data.get("fork")), license=(data.get("license") or {}).get("spdx_id"),
                   languages=langs, swift_bytes=sb, swift_share=round(sb/tot,4),
                   flags=[f for f,on in (("archived",data.get("archived")),("fork",data.get("fork"))) if on])
        if data.get("disabled"): rec.update(included=False, reason="disabled")
        elif pushed and pushed < CUTOFF: rec.update(included=False, reason="stale")
        elif sb < 3000 or rec["swift_share"] < 0.2: rec.update(included=False, reason="not_swift")
        else: rec.update(included=True, reason="ok")
        fmeta.write(json.dumps(rec)+"\n"); fmeta.flush()
        if i % 50 == 0: print(f"  {i}/{len(new)} processed", flush=True)
    fmeta.close()

    incl = []
    for ln in open(META):
        d = json.loads(ln)
        if d.get("included"):
            incl.append({k: d.get(k) for k in ("owner","repo","full_name","default_branch","stars",
                         "pushed_at","swift_bytes","swift_share","languages","flags","license",
                         "found_by")} | {"categories": ["(discovered)"], "discovered_via":"github-code-search"})
    incl.sort(key=lambda x:-x["stars"])
    json.dump(incl, open(OUT,"w"), indent=2)
    from collections import Counter
    reasons = Counter(json.loads(l)["reason"] for l in open(META))
    print(f"\nNEW repos passing gate: {len(incl)}  | reasons={dict(reasons)}")
    print("  top new by stars:", [f"{r['full_name']}({r['stars']})" for r in incl[:8]])

if __name__ == "__main__":
    main()
