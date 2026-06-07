#!/usr/bin/env python3
"""Stage 5 — Aggregate all repos/*.jsonl into a sharded, navigable catalog.
Matches raw occurrences against sdk_catalog.json dimensions; builds per-symbol usage indexes
(permalinks + arg-shapes + availability), per-repo profiles, custom-component inventory,
protocol-conformance adoption, and insights (modern stack, deprecated usage, modernity, etc.).
Re-runnable without re-cloning. Outputs to catalog/.
"""
import json, os, glob, re, math, hashlib
from collections import defaultdict, Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SDK  = json.load(open(os.path.join(ROOT,"sdk_catalog.json")))
DIM  = {k: set(v) for k,v in SDK["dimensions"].items()}
AVAIL = SDK.get("availability", {})
STYLE_CAT = SDK.get("style_categories", {})
# author-authority enrichment (optional; falls back to stars-only ranking if absent)
try: AUTH = json.load(open(os.path.join(ROOT,"data","07_repo_authority.json")))
except Exception: AUTH = {}
# symbols that prove a repo is a macOS app (vs iOS/library)
MACOS_SIGNALS = {"MenuBarExtra","Settings","NSViewRepresentable","NSViewControllerRepresentable",
                 "NSHostingController","windowStyle","menuBarExtraStyle","windowResizability",
                 "NSApplicationDelegateAdaptor","HSplitView","windowToolbarStyle","onExitCommand"}
DEMO_RE = re.compile(r'sample|example|tutorial|demo|playground', re.I)
# Container/builder views almost always called with a trailing closure: `Form { … }`. A `Form(message:…)`
# call WITHOUT a trailing closure is a same-named custom struct (false positive) — require the closure.
CONTAINER_TYPES = {"Form","List","Section","Group","VStack","HStack","ZStack","NavigationStack",
                   "NavigationSplitView","NavigationView","ScrollView","Table","Grid","GridRow","TabView",
                   "Menu","DisclosureGroup","GroupBox","LazyVGrid","LazyHGrid","LazyVStack","LazyHStack",
                   "WindowGroup","Window","Settings","MenuBarExtra","ToolbarItem","ToolbarItemGroup"}
COOC_NOISE = {"immersionStyle","ornament","onImmersionChange","dragConfiguration"}  # visionOS / non-macOS noise
OUT  = os.path.join(ROOT,"catalog")
EX_CAP = 25
ENVKEY = re.compile(r'\\\.([A-Za-z_]\w*)')
UI_IMPORTS = {"SwiftUI", "SwiftUICore", "Charts"}
DIMS = ("modifiers","types","valueBuilders","macros","styleValues","propertyWrappers","environmentKeys")
SETTINGS_RE = re.compile(r'(setting|preference|config|general|advanced)', re.I)
# form/settings vocabulary worth surfacing inside a settings screen
FORM_VOCAB = {"Form","TabView","GroupBox","Section","LabeledContent","Toggle","Picker","TextField",
              "SecureField","Slider","Stepper","ColorPicker","DatePicker","Settings","NavigationSplitView",
              "List","Grid","Table","KeyboardShortcut","Divider","Spacer","DisclosureGroup"}

def macos_ver(s):
    try:
        parts = str(s).split('.')
        return int(parts[0]) + (int(parts[1])/100.0 if len(parts) > 1 else 0.0)
    except: return 0.0

def dim_for(occ):
    """Map an occurrence to (dimension, symbol) or None. valueBuilders is checked after the
    primary kind so genuine View modifiers / style values win on any name collision."""
    k, s = occ["kind"], occ["sym"]
    if k == "modifier":
        if s in DIM["modifiers"]: return ("modifiers", s)
        if s in DIM["valueBuilders"]: return ("valueBuilders", s)
        return None
    if k == "type":
        if s not in DIM["types"]: return None
        if s in CONTAINER_TYPES and not occ.get("trailingClosure"): return None  # custom same-named struct
        return ("types", s)
    if k == "macro":  return ("macros", s) if s in DIM["macros"] else None
    if k == "member" and occ.get("implicit"):
        # leading-dot implicit member: style value or value-builder (NOT a model property access)
        if s in DIM["styleValues"]: return ("styleValues", s)
        if s in DIM["valueBuilders"]: return ("valueBuilders", s)
        return None
    if k == "attribute": return ("propertyWrappers", s) if s in DIM["propertyWrappers"] else None
    if k == "keypath":   return ("environmentKeys", s) if s in DIM["environmentKeys"] else None
    return None

def arg_shape(occ):
    a = occ.get("args")
    if a is None: return None
    if not a and occ.get("trailingClosure"): return "{ }"   # trailing-closure-only call (e.g. VStack { })
    return "(" + ", ".join(a) + ")"

def main():
    os.makedirs(OUT, exist_ok=True); os.makedirs(os.path.join(OUT,"by_repo"), exist_ok=True)
    index = {d: defaultdict(lambda: {"total":0, "repos":Counter(), "examples":{},
                                     "arg_shapes":Counter()}) for d in DIMS}
    custom = []
    bridges = []                       # NSViewRepresentable/etc. AppKit bridges
    settings_views = []                # settings/preferences screens
    scope_vocab = defaultdict(lambda: defaultdict(set))  # [repo][scope] -> {FORM_VOCAB syms}
    conformances = defaultdict(lambda: {"repos":Counter(), "examples":[]})
    repo_meta = {}; repo_profile = {}
    unmatched = {"modifier": Counter(), "attribute": Counter(), "type": Counter(), "member": Counter()}
    unmatched_repos = {k: defaultdict(set) for k in unmatched}
    deprecated_usage = defaultdict(lambda: {"repos":Counter(), "renamed": AVAIL.get("","")})

    for fp in sorted(glob.glob(os.path.join(ROOT,"repos","*.jsonl"))):
        lines = open(fp).read().splitlines()
        if not lines: continue
        try: head = json.loads(lines[0])
        except: continue
        if head.get("type") != "repo": continue
        repo = head["full_name"]; base = head["permalink_base"]; stars = head.get("stars",0)
        repo_meta[repo] = {"stars":stars, "categories":head.get("categories",[]),
                           "sha":head.get("sha"), "pushed_at":head.get("pushed_at")}
        prof = {d:set() for d in DIMS}
        prof.update(customComponents=0, imports=set(), loc=0, max_macos=0.0, deprecated=set())
        for ln in lines[1:]:
            try: obj = json.loads(ln)
            except: continue
            if obj.get("type") == "done": continue
            path = obj.get("path",""); imps = obj.get("imports",[])
            prof["imports"].update(imps); prof["loc"] += obj.get("loc",0)
            if not (UI_IMPORTS & set(imps)): continue
            for occ in obj.get("occurrences",[]):
                # env key from @Environment(\.key) attribute args
                if occ["kind"]=="attribute" and occ["sym"]=="Environment" and occ.get("args"):
                    for a in occ["args"]:
                        for key in ENVKEY.findall(a or ""):
                            if key in DIM["environmentKeys"]:
                                _add(index["environmentKeys"][key], repo, base, path, occ)
                                prof["environmentKeys"].add(key)
                m = dim_for(occ)
                if m:
                    dim, sym = m
                    _add(index[dim][sym], repo, base, path, occ)
                    sh = arg_shape(occ)
                    if sh is not None: index[dim][sym]["arg_shapes"][sh] += 1
                    prof[dim].add(sym)
                    if sym in FORM_VOCAB and occ.get("scope"):
                        scope_vocab[repo][occ["scope"]].add(sym)
                    av = AVAIL.get(sym, {})
                    iv = macos_ver(av.get("introduced_macos","")) if av else 0.0
                    if iv > prof["max_macos"]: prof["max_macos"] = iv
                    if av.get("deprecated"):
                        deprecated_usage[sym]["repos"][repo]+=1
                        deprecated_usage[sym]["renamed"]=av.get("renamed","")
                        prof["deprecated"].add(sym)
                elif occ["kind"] in unmatched and occ["sym"][:1].isalpha():
                    unmatched[occ["kind"]][occ["sym"]] += 1
                    unmatched_repos[occ["kind"]][occ["sym"]].add(repo)
            for d in obj.get("decls",[]):
                plink = f"{base}{path}#L{d['line']}"
                custom.append({"name":d["name"],"kind":d["kind"],"repo":repo,
                               "conforms":d.get("conforms",[]),"wrappers":d.get("wrappers",[]),
                               "permalink": plink})
                prof["customComponents"] += 1
                if d["kind"] == "bridge":
                    bridges.append({"name":d["name"],"repo":repo,"conforms":d.get("conforms",[]),
                                    "permalink":plink})
                if d["kind"] in ("view","viewbuilder") and SETTINGS_RE.search(d["name"]):
                    settings_views.append({"name":d["name"],"repo":repo,"permalink":plink,
                                           "wrappers":d.get("wrappers",[])})
                for c in d.get("conforms",[]):
                    cb = c.split(".")[-1]
                    if cb in DIM["protocols"]:
                        conformances[cb]["repos"][repo]+=1
                        if len(conformances[cb]["examples"]) < EX_CAP:
                            conformances[cb]["examples"].append(
                                {"repo":repo,"name":d["name"],"permalink":f"{base}{path}#L{d['line']}"})
        repo_profile[repo] = prof
        # platform + modernity classification (needs the finished profile)
        repo_meta[repo]["min_macos"] = prof["max_macos"]
        repo_meta[repo]["deprecated"] = len(prof["deprecated"]) > 0
        is_mac = ("AppKit" in prof["imports"]) or bool(
            MACOS_SIGNALS & (prof["types"] | prof["modifiers"] | prof["propertyWrappers"]))
        repo_meta[repo]["platform"] = "macos" if is_mac else "other"
        _write_repo_profile(repo, prof, repo_meta[repo])

    # ---- composite quality score per repo (author-authority + stars + modernity + recency) ----
    scores = {r: repo_score(r, repo_meta) for r in repo_meta}

    # ---- lift-based co-occurrence: which APIs are used *disproportionately* with each symbol ----
    # exclude valueBuilders (color/font literals like .yellow/.headline are noise as "used-with")
    repo_syms = {r: (p["modifiers"] | p["types"] | p["propertyWrappers"])
                 for r, p in repo_profile.items()}
    N = len(repo_profile) or 1
    gfreq = Counter()
    for s in repo_syms.values(): gfreq.update(s)
    UBIQ = {s for s, c in gfreq.items() if c / N > 0.80}   # frame/padding/font… — no signal
    def cooccurs(sym, repos_using):
        n = len(repos_using)
        if n < 5: return []
        c = Counter()
        for r in repos_using: c.update(repo_syms.get(r, ()))
        out = []
        for b, cc in c.items():
            if b == sym or b in UBIQ or b in COOC_NOISE or cc < 5: continue
            lift = (cc / n) / (gfreq[b] / N)
            if lift >= 1.5: out.append({"sym": b, "lift": round(lift, 1), "repos": cc})
        return sorted(out, key=lambda x: -x["lift"])[:8]

    # ---- per-dimension shards ----
    sizes = {}; ex_index = {}
    for dim, d in index.items():
        shard = {}
        for sym, rec in d.items():
            ranked = _rank_examples(rec["examples"], scores, repo_meta)
            for e in ranked:
                ex_index[e["id"]] = {"permalink":e["permalink"], "repo":e["repo"],
                                     "path":e["path"], "line":e["line"], "src":e["src"],
                                     "sha": repo_meta.get(e["repo"],{}).get("sha")}
            entry = {"total_uses":rec["total"], "repo_count":len(rec["repos"]),
                     "low_corpus": len(rec["repos"]) < 10,
                     "top_repos":rec["repos"].most_common(10), "examples":ranked,
                     "co_occurs_with":cooccurs(sym, list(rec["repos"]))}
            if rec["arg_shapes"]:
                _tot = sum(rec["arg_shapes"].values()) or 1
                entry["arg_shapes"] = [{"shape":s,"uses":n} for s,n in rec["arg_shapes"].most_common(15)
                                       if n/_tot >= 0.01]   # drop <1% noise shapes
            av = AVAIL.get(sym)
            if av: entry["availability"] = av
            if dim == "styleValues": entry["category"] = STYLE_CAT.get(sym,"other")
            shard[sym] = entry
        shard = dict(sorted(shard.items(), key=lambda kv:-kv[1]["repo_count"]))
        json.dump(shard, open(os.path.join(OUT,f"{dim}.json"),"w"), indent=1)
        sizes[dim] = len(shard)
    json.dump(ex_index, open(os.path.join(OUT,"examples_index.json"),"w"))

    custom.sort(key=lambda c:(c["kind"], c["repo"], c["name"]))
    json.dump(custom, open(os.path.join(OUT,"customComponents.json"),"w"), indent=1)

    conf_out = {p:{"repo_count":len(v["repos"]),"top_repos":v["repos"].most_common(10),
                   "examples":v["examples"]}
                for p,v in sorted(conformances.items(), key=lambda kv:-len(kv[1]["repos"]))}
    json.dump(conf_out, open(os.path.join(OUT,"conformances.json"),"w"), indent=1)

    # AppKit/UIKit bridge inventory
    bridges.sort(key=lambda b:(b["repo"], b["name"]))
    json.dump({"count":len(bridges), "repos":len({b["repo"] for b in bridges}), "bridges":bridges},
              open(os.path.join(OUT,"bridges.json"),"w"), indent=1)

    # settings/preferences screens + the form vocabulary used inside each
    for s in settings_views:
        s["form_vocab"] = sorted(scope_vocab[s["repo"]].get(s["name"], set()))
    settings_views.sort(key=lambda s:(-len(s["form_vocab"]), s["repo"]))
    form_freq = Counter(v for s in settings_views for v in s["form_vocab"])
    json.dump({"count":len(settings_views), "repos":len({s["repo"] for s in settings_views}),
               "form_vocab_frequency":form_freq.most_common(),
               "screens":settings_views},
              open(os.path.join(OUT,"settings.json"),"w"), indent=1)

    insights = _insights(repo_profile, repo_meta, unmatched, unmatched_repos, custom, deprecated_usage)
    json.dump(insights, open(os.path.join(OUT,"insights.json"),"w"), indent=2)
    json.dump(_rankings(repo_profile, repo_meta), open(os.path.join(OUT,"rankings.json"),"w"), indent=2)

    n_members = sum(1 for c in custom if c["kind"] == "viewbuilder")
    idx = {"sdk":SDK["sdk"], "modules":SDK["modules"], "repos_analyzed":len(repo_meta),
           "custom_components":len(custom) - n_members,   # true components (View/App/Style/bridge/…)
           "view_builder_members":n_members,              # body / some-View helper funcs
           "custom_components_total_incl_members":len(custom),
           "dimension_sizes":sizes, "sdk_counts":SDK["counts"],
           "shards":{d:f"{d}.json" for d in index},
           "files":{"customComponents":"customComponents.json","conformances":"conformances.json",
                    "bridges":"bridges.json","settings":"settings.json",
                    "insights":"insights.json","rankings":"rankings.json","by_repo":"by_repo/"}}
    json.dump(idx, open(os.path.join(OUT,"index.json"),"w"), indent=2)
    print(f"catalog: {len(repo_meta)} repos, {len(custom)} custom components")
    print("dimension sizes:", sizes)
    print("fully-deprecated APIs in use:", len([s for s in deprecated_usage]))

def _add(rec, repo, base, path, occ):
    rec["total"]+=1; rec["repos"][repo]+=1
    ln = occ.get("line")
    eid = "ex_" + hashlib.md5(f"{repo}:{path}:{ln}".encode()).hexdigest()[:10]
    rec["examples"].setdefault(repo, {"id":eid, "repo":repo, "path":path, "line":ln,
        "permalink": f"{base}{path}#L{ln}", "src":occ.get("src",""), "shape": arg_shape(occ)})

def repo_score(r, meta):
    """Composite quality score in [0,1]: author authority + stars dominate; modernity, recency,
    contributor count contribute; deprecated-usage / demo-repo / non-macOS are penalized."""
    m = meta[r]; a = AUTH.get(r, {})
    stars_n  = math.log10(m.get("stars",0)+1)/5.0                       # /log10(1e5)
    author_n = math.log10(a.get("author_authority",0)+1)/6.0           # /log10(1e6)
    author_n *= min(1.0, (m.get("stars",0)+10)/60.0)                   # damp authority for very-low-star repos
    modern_n = min(1.0, max(0.0, (m.get("min_macos",0)-10)/16.0))      # macOS 10→0 … 26→1
    py = int((m.get("pushed_at") or "2023")[:4] or 2023)
    recency_n = min(1.0, max(0.0, (py-2023)/3.0))
    contrib_n = math.log10(a.get("contributor_count",0)+1)/2.5         # /log10(~300)
    pen = (0.30 if m.get("deprecated") else 0.0) \
        + (0.20 if DEMO_RE.search(r) else 0.0) \
        + (0.25 if m.get("platform") != "macos" else 0.0)
    return round(max(0.0, 0.30*min(1,stars_n) + 0.30*min(1,author_n) + 0.15*modern_n
                         + 0.15*recency_n + 0.10*min(1,contrib_n) - pen), 4)

def _provenance(r, meta, scores):
    m = meta[r]; a = AUTH.get(r, {})
    mm = m.get("min_macos",0)
    return {"stars":m.get("stars",0), "author_authority":a.get("author_authority",0),
            "min_macos": (f"{mm:.2f}".rstrip('0').rstrip('.') if mm else None),
            "platform":m.get("platform","?"), "score":scores.get(r,0)}

def _poor(src):
    s = (src or "").strip()
    return (not s) or len(s) < 12 or s[-1] in "({,"   # truncated multi-line / fragment

def _rank_examples(examples, scores, meta):
    # complete-snippet first, then diversity across arg-shapes, then composite quality score
    items = list(examples.values())
    items.sort(key=lambda e: (1 if _poor(e.get("src","")) else 0,
                              -scores.get(e["repo"],0), -meta.get(e["repo"],{}).get("stars",0), e["repo"]))
    seen, picked, rest = set(), [], []
    for e in items:
        sh = e.get("shape")
        if sh not in seen: seen.add(sh); picked.append(e)
        else: rest.append(e)
    out = (picked + rest)[:EX_CAP]
    for e in out: e["provenance"] = _provenance(e["repo"], meta, scores)
    return out

def _write_repo_profile(repo, prof, meta):
    a = AUTH.get(repo, {})
    out = {"repo":repo, "stars":meta["stars"], "categories":meta["categories"], "sha":meta["sha"],
           "platform":meta.get("platform"), "author_authority":a.get("author_authority",0),
           "contributor_count":a.get("contributor_count",0),
           "top_contributors":a.get("top_contributors",[]),
           "loc":prof["loc"], "custom_components":prof["customComponents"],
           "imports": sorted(prof["imports"]),
           "min_macos_inferred": f"{prof['max_macos']:.2f}".rstrip('0').rstrip('.') if prof['max_macos'] else None,
           "deprecated_apis_used": sorted(prof["deprecated"]),
           "unique": {d: sorted(prof[d]) for d in DIMS},
           "counts": {d: len(prof[d]) for d in DIMS}}
    out["total_unique_apis"] = sum(out["counts"].values())
    json.dump(out, open(os.path.join(OUT,"by_repo",f"{repo.replace('/','__')}.json"),"w"), indent=1)

def _insights(prof, meta, unmatched, unmatched_repos, custom, deprecated_usage):
    repos = list(prof); n = len(repos) or 1
    has = lambda r,d,s: s in prof[r][d]
    anyof = lambda r,d,ss: any(s in prof[r][d] for s in ss)
    pct = lambda cond: round(100*sum(1 for r in repos if cond(r))/n, 1)
    modern = {"repos": n,
        "Observable_macro": pct(lambda r: has(r,"propertyWrappers","Observable")),
        "StateObject": pct(lambda r: has(r,"propertyWrappers","StateObject")),
        "ObservedObject": pct(lambda r: has(r,"propertyWrappers","ObservedObject")),
        "NavigationStack_or_Split": pct(lambda r: anyof(r,"types",["NavigationStack","NavigationSplitView"])),
        "NavigationView(legacy)": pct(lambda r: has(r,"types","NavigationView")),
        "SwiftData(@Model)": pct(lambda r: has(r,"propertyWrappers","Model") or "SwiftData" in prof[r]["imports"]),
        "MenuBarExtra": pct(lambda r: has(r,"types","MenuBarExtra")),
        "Settings_scene": pct(lambda r: has(r,"types","Settings")),
        "searchable": pct(lambda r: has(r,"modifiers","searchable")),
        "AppKit_bridging": pct(lambda r: "AppKit" in prof[r]["imports"]),
        "Charts_imported": pct(lambda r: "Charts" in prof[r]["imports"]),
        "uses_deprecated_api": pct(lambda r: len(prof[r]["deprecated"])>0)}
    discovered = {kind: [{"sym":s,"uses":unmatched[kind][s],"repos":len(unmatched_repos[kind][s])}
                         for s,_ in unmatched[kind].most_common(40) if len(unmatched_repos[kind][s])>=3]
                  for kind in unmatched}
    dep = sorted(({"sym":s,"renamed":v["renamed"],"repos":len(v["repos"]),
                   "top_repos":v["repos"].most_common(8)} for s,v in deprecated_usage.items()),
                 key=lambda x:-x["repos"])
    def co(dim, anchor, top=12):
        rs = [r for r in repos if anchor in prof[r][dim]]
        c = Counter()
        for r in rs:
            for m in prof[r]["modifiers"]: c[m]+=1
        return {"anchor":anchor,"anchor_repos":len(rs),
                "co_modifiers":[{"sym":s,"repos":k} for s,k in c.most_common(top)]}
    cat_mods = defaultdict(list)
    for r in repos:
        for cat in meta[r]["categories"]: cat_mods[cat].append(len(prof[r]["modifiers"]))
    cat_fp = dict(sorted({c:{"repos":len(v),"avg_unique_modifiers":round(sum(v)/len(v),1)}
                          for c,v in cat_mods.items() if len(v)>=2}.items(),
                         key=lambda kv:-kv[1]["avg_unique_modifiers"]))
    return {"modern_stack_adoption_pct":modern,
            "deprecated_api_usage":dep,
            "discovered_external_api":discovered,
            "co_occurrence":[co("types","MenuBarExtra"),co("modifiers","searchable"),
                             co("types","NavigationSplitView")],
            "custom_components_by_kind":dict(Counter(c["kind"] for c in custom)),
            "category_fingerprint":cat_fp}

def _rankings(prof, meta):
    rows=[{"repo":r,"stars":meta[r]["stars"],"loc":prof[r]["loc"],
           "total_unique_apis":sum(len(prof[r][d]) for d in DIMS),
           "modifiers":len(prof[r]["modifiers"]),"types":len(prof[r]["types"]),
           "valueBuilders":len(prof[r]["valueBuilders"]),
           "custom_components":prof[r]["customComponents"],
           "min_macos": f"{prof[r]['max_macos']:.2f}".rstrip('0').rstrip('.') if prof[r]['max_macos'] else None}
          for r in prof]
    return {"by_total_unique_apis":sorted(rows,key=lambda x:-x["total_unique_apis"])[:50],
            "by_modifier_breadth":sorted(rows,key=lambda x:-x["modifiers"])[:50],
            "by_custom_components":sorted(rows,key=lambda x:-x["custom_components"])[:50],
            "most_modern_stack":sorted([r for r in rows if r["min_macos"] and r["total_unique_apis"]>=30],
                                       key=lambda x:-macos_ver(x["min_macos"]))[:30]}

if __name__ == "__main__":
    main()
