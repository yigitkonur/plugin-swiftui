#!/usr/bin/env python3
"""Stage 7 — Author-authority enrichment.

A contributor's pull = stars of the projects they OWN + stars of the projects they've CONTRIBUTED to.
A repo inherits the authority of its strongest contributor. This gives a quality signal far better than
raw use-count (which surfaces iOS samples / libraries).

Phase 1: per scanned repo, fetch top-K contributors (REST).        cache: data/07_contributors.jsonl
Phase 2: per unique contributor login, aggregate stars (GraphQL).  cache: data/07_authors_cache.jsonl
Phase 3: per repo, author_authority = max(login score over its top-K).
Outputs: data/07_authors.json (login->score), data/07_repo_authority.json (full_name->{...}).

Resumable (both caches skip done) and rate-limit aware (GraphQL batched ~8 logins/request).
"""
import json, os, subprocess, time, glob, argparse

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, "..")
CONTRIB = os.path.join(ROOT, "data", "07_contributors_v2.jsonl")   # now stores contribution counts
ACACHE  = os.path.join(ROOT, "data", "07_authors_cache.jsonl")
OUT_A   = os.path.join(ROOT, "data", "07_authors.json")
OUT_R   = os.path.join(ROOT, "data", "07_repo_authority.json")
BOTS = {"actions-user", "github-actions[bot]", "dependabot[bot]", "web-flow"}

def gh_json(args):
    r = subprocess.run(["gh"] + args, capture_output=True, text=True)
    if r.returncode != 0:
        return None, r.stderr
    try: return json.loads(r.stdout), None
    except Exception: return None, "parse"

def corpus_repos():
    repos = []
    for f in sorted(glob.glob(os.path.join(ROOT, "repos", "*.jsonl"))):
        try:
            h = json.loads(open(f).readline())
            if h.get("full_name"): repos.append(h["full_name"])
        except Exception: pass
    return repos

def load_jsonl_map(path, key):
    m = {}
    if os.path.exists(path):
        for ln in open(path):
            try: d = json.loads(ln); m[d[key]] = d
            except Exception: pass
    return m

# ---------- Phase 1: contributors (with contribution counts) ----------
def phase1_contributors(repos, K):
    done = load_jsonl_map(CONTRIB, "repo")
    f = open(CONTRIB, "a")
    for i, full in enumerate(repos, 1):
        if full in done: continue
        data, err = gh_json(["api", f"repos/{full}/contributors?per_page={K*3}",
                             "--jq", "[.[] | {login, contributions}]"])
        time.sleep(0.05)
        contribs = [c for c in (data or []) if c.get("login")
                    and not c["login"].endswith("[bot]") and c["login"] not in BOTS][:K]
        f.write(json.dumps({"repo": full, "contribs": contribs}) + "\n"); f.flush()
        if i % 100 == 0: print(f"  contributors {i}/{len(repos)}", flush=True)
    f.close()
    return load_jsonl_map(CONTRIB, "repo")

# ---------- Phase 2: author scores (GraphQL, batched) ----------
USER_FRAGMENT = """
  a%d: user(login: %s) {
    repositories(first: 100, ownerAffiliations: OWNER, orderBy: {field: STARGAZERS, direction: DESC}) { nodes { stargazerCount } }
    repositoriesContributedTo(first: 100, contributionTypes: [COMMIT, PULL_REQUEST], orderBy: {field: STARGAZERS, direction: DESC}) { nodes { stargazerCount } }
  }"""

def phase2_scores(logins, batch=8):
    cache = load_jsonl_map(ACACHE, "login")
    todo = [l for l in logins if l not in cache]
    f = open(ACACHE, "a")
    print(f"  {len(todo)} unique logins to score ({len(cache)} cached)", flush=True)
    for i in range(0, len(todo), batch):
        chunk = todo[i:i+batch]
        q = "query {" + "".join(USER_FRAGMENT % (j, json.dumps(l)) for j, l in enumerate(chunk)) + "\n}"
        for attempt in range(4):
            data, err = gh_json(["api", "graphql", "-f", f"query={q}"])
            if data is not None: break
            if err and ("rate limit" in err.lower() or "403" in err):
                time.sleep(20*(attempt+1)); continue
            break
        d = (data or {}).get("data", data) or {}
        for j, login in enumerate(chunk):
            u = d.get(f"a{j}")
            if not u:
                score = 0
            else:
                owned = sum(n["stargazerCount"] for n in u["repositories"]["nodes"])
                contrib = sum(n["stargazerCount"] for n in u["repositoriesContributedTo"]["nodes"])
                score = owned + contrib
            f.write(json.dumps({"login": login, "score": score}) + "\n")
        f.flush()
        if (i // batch) % 20 == 0: print(f"  scored {min(i+batch,len(todo))}/{len(todo)}", flush=True)
        time.sleep(0.3)
    f.close()
    return {l: d["score"] for l, d in load_jsonl_map(ACACHE, "login").items()}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--k", type=int, default=3, help="top contributors per repo")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    repos = corpus_repos()
    if args.limit: repos = repos[:args.limit]
    print(f"corpus repos: {len(repos)}")

    contrib = phase1_contributors(repos, args.k)
    unique = sorted({c["login"] for full in repos for c in contrib.get(full, {}).get("contribs", [])})
    scores = phase2_scores(unique, batch=8)

    json.dump(scores, open(OUT_A, "w"))
    authority = {}
    for full in repos:
        owner = full.split("/")[0]
        cs = contrib.get(full, {}).get("contribs", [])
        total_c = sum(c.get("contributions", 0) for c in cs) or 1
        # owner gets full credit (they built it); a non-owner contributor counts only in proportion
        # to their commit share — so a 1-commit drive-by by a mega-author can no longer dominate.
        owner_score = next((scores.get(c["login"], 0) for c in cs if c["login"] == owner), 0)
        weighted = [scores.get(c["login"], 0) * (c.get("contributions", 0) / total_c) for c in cs]
        authority[full] = {
            "author_authority": int(max([owner_score] + weighted)) if cs else 0,
            "author_authority_raw_max": max((scores.get(c["login"], 0) for c in cs), default=0),
            "contributor_count": len(cs),
            "top_contributors": [{"login": c["login"], "score": scores.get(c["login"], 0),
                                  "contributions": c.get("contributions", 0)} for c in cs],
        }
    json.dump(authority, open(OUT_R, "w"), indent=1)
    top = sorted(authority.items(), key=lambda kv: -kv[1]["author_authority"])[:8]
    print(f"\nwrote {OUT_R}: {len(authority)} repos")
    print("  highest-authority repos:", [(k, v["author_authority"]) for k, v in top])

if __name__ == "__main__":
    main()
