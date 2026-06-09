#!/usr/bin/env python3
"""Stage 4 — Orchestrate clone ▸ scan ▸ delete over the included repos.
Resumable (skips repos with a complete JSONL), disk-bounded (clone then delete),
bounded parallelism. Writes repos/{owner}__{repo}.jsonl + run_state.jsonl + errors.jsonl.

Usage:
  scripts/04_run.py [--jobs 6] [--only owner/repo,owner/repo] [--limit N]
"""
import json, os, sys, subprocess, tempfile, shutil, time, argparse
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCANNER = os.path.join(ROOT, "swiftui-scan/.build/release/swiftui-scan")
INCL = os.path.join(ROOT, "data/01_included.json")
OUTDIR = os.path.join(ROOT, "repos")
STATE = os.path.join(ROOT, "run_state.jsonl")
ERRORS = os.path.join(ROOT, "errors.jsonl")
PRUNE = {".git",".build","Pods","Carthage","DerivedData","Vendor","vendor",
         "third_party","ThirdParty","node_modules","Submodules","Frameworks"}
GEN_SUFFIX = (".generated.swift",".pb.swift","+CoreDataClass.swift","+CoreDataProperties.swift")

def log(fp, obj):
    with open(fp, "a") as f: f.write(json.dumps(obj)+"\n")

def jsonl_complete(path):
    if not os.path.exists(path): return False
    try:
        last = subprocess.run(["tail","-1",path], capture_output=True, text=True).stdout
        return json.loads(last).get("type") == "done"
    except Exception:
        return False

def swift_files(root):
    out = []
    for dp, dns, fns in os.walk(root, followlinks=False):
        dns[:] = [d for d in dns if d not in PRUNE]
        for fn in fns:
            if fn.endswith(".swift") and not fn.endswith(GEN_SUFFIX):
                out.append(os.path.join(dp, fn))
    return out

def clone(full, tmp):
    url = f"https://github.com/{full}.git"
    env = {**os.environ, "GIT_LFS_SKIP_SMUDGE": "1", "GIT_TERMINAL_PROMPT": "0"}
    for attempt in range(2):
        r = subprocess.run(["git","clone","--depth","1","--single-branch","--quiet",url,tmp],
                           capture_output=True, text=True, env=env, timeout=300)
        if r.returncode == 0: return True, ""
        shutil.rmtree(tmp, ignore_errors=True); os.makedirs(tmp, exist_ok=True)
        time.sleep(2*(attempt+1))
    return False, r.stderr.strip()[:300]

def process(repo):
    owner, name = repo["owner"], repo["repo"]
    full = repo.get("full_name", f"{owner}/{name}")
    out = os.path.join(OUTDIR, f"{owner}__{name}.jsonl")
    if jsonl_complete(out):
        return ("skip", full)
    tmp = tempfile.mkdtemp(prefix="scan_", dir="/tmp")
    t0 = time.time()
    try:
        ok, err = clone(full, tmp)
        if not ok:
            log(ERRORS, {"repo": full, "stage":"clone", "error": err})
            return ("error", full)
        sha = subprocess.run(["git","-C",tmp,"rev-parse","HEAD"],
                             capture_output=True, text=True).stdout.strip()
        files = swift_files(tmp)
        if not files:
            log(ERRORS, {"repo": full, "stage":"scan", "error":"no_swift_files"})
            return ("error", full)
        # run scanner
        paths = "\n".join(files).encode()
        try:
            r = subprocess.run([SCANNER], input=paths, capture_output=True, timeout=300)
        except subprocess.TimeoutExpired:
            log(ERRORS, {"repo": full, "stage":"scan", "error":"timeout"})
            return ("error", full)
        permalink_base = f"https://github.com/{full}/blob/{sha}/"
        tmp_out = out + ".tmp"
        nfiles = nocc = 0
        with open(tmp_out, "w") as fo:
            fo.write(json.dumps({
                "type":"repo","owner":owner,"repo":name,"full_name":full,"sha":sha,
                "default_branch":repo.get("default_branch"),"stars":repo.get("stars"),
                "pushed_at":repo.get("pushed_at"),"categories":repo.get("categories"),
                "languages":repo.get("languages"),"swift_share":repo.get("swift_share"),
                "discovered_via":repo.get("discovered_via","awesome-mac"),
                "found_by":repo.get("found_by"),
                "scanner":"swiftsyntax-603.0.1","permalink_base":permalink_base})+"\n")
            for line in r.stdout.decode("utf-8","ignore").splitlines():
                if not line.strip(): continue
                try: obj = json.loads(line)
                except: continue
                # absolute path -> repo-relative
                ap = obj.get("path","")
                obj["path"] = os.path.relpath(ap, tmp) if ap.startswith(tmp) else ap
                nfiles += 1; nocc += len(obj.get("occurrences",[]))
                fo.write(json.dumps(obj)+"\n")
            fo.write(json.dumps({"type":"done","files":nfiles,"occurrences":nocc})+"\n")
        os.replace(tmp_out, out)
        dt = round(time.time()-t0,1)
        log(STATE, {"repo": full, "status":"done", "files":nfiles, "occurrences":nocc, "secs":dt})
        return ("done", full)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", type=int, default=6)
    ap.add_argument("--only", default="")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--included", default=INCL, help="path to the included-repos JSON to scan")
    args = ap.parse_args()

    if not os.path.exists(SCANNER):
        sys.exit(f"scanner not built: {SCANNER}")
    os.makedirs(OUTDIR, exist_ok=True)
    repos = json.load(open(args.included))
    if args.only:
        want = {s.strip().lower() for s in args.only.split(",")}
        repos = [r for r in repos if f"{r['owner']}/{r['repo']}".lower() in want
                 or r.get("full_name","").lower() in want]
    if args.limit: repos = repos[:args.limit]

    print(f"processing {len(repos)} repos with {args.jobs} workers", flush=True)
    counts = {"done":0,"skip":0,"error":0}
    done_n = 0
    with ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futs = {ex.submit(process, r): r for r in repos}
        for fut in as_completed(futs):
            status, full = fut.result()
            counts[status] += 1; done_n += 1
            if done_n % 10 == 0 or status == "error":
                print(f"  [{done_n}/{len(repos)}] {status:5} {full}  totals={counts}", flush=True)
    print(f"FINISHED: {counts}")

if __name__ == "__main__":
    main()
