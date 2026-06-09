#!/usr/bin/env python3
"""Stage 2b — Extract per-symbol availability/deprecation from the SwiftUI/Core symbol graphs
and merge an `availability` map into sdk_catalog.json:
  name -> {introduced_macos: "13.0", deprecated: bool, renamed: "<replacement>"}
Keyed by symbol base-name (the same token we match in repos). Across overloads:
  introduced_macos = earliest; deprecated = True only if ALL public overloads are deprecated;
  renamed = first non-empty replacement seen among deprecated overloads.
"""
import json, os, subprocess
from collections import defaultdict

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..")
SG = [os.path.join(ROOT,"sg",f) for f in
      ("SwiftUI.symbols.json","SwiftUICore.symbols.json","Observation.symbols.json",
       "SwiftData.symbols.json","Charts.symbols.json")]
CAT = os.path.join(ROOT,"sdk_catalog.json")

JQ = r'''
.symbols[]
| (.names.title) as $t
| ([.availability[]? | select(.domain=="macOS")][0]) as $m
| ([.availability[]? | select((.deprecated!=null) or (.isUnconditionallyDeprecated==true))][0]) as $dep
| [ $t,
    (if $m.introduced==null then "" else "\($m.introduced.major).\($m.introduced.minor // 0)" end),
    (if $dep==null then "0" else "1" end),
    ($dep.renamed // "")
  ] | @tsv
'''

def strip(t): return t.split('(')[0]

def main():
    intro = {}                 # name -> (major,minor) earliest
    dep_all = defaultdict(lambda: [0,0])  # name -> [n_overloads, n_deprecated]
    renamed = {}
    for f in SG:
        if not os.path.exists(f): continue
        r = subprocess.run(["jq","-r",JQ,f], capture_output=True, text=True)
        for ln in r.stdout.splitlines():
            p = ln.split('\t')
            if len(p) < 4: continue
            name = strip(p[0])
            if not name or not name.isidentifier() or name.startswith('_'): continue
            # introduced (earliest)
            if p[1]:
                try:
                    mj, mn = p[1].split('.'); v = (int(mj), int(mn))
                    if name not in intro or v < intro[name]: intro[name] = v
                except: pass
            d = dep_all[name]; d[0]+=1; d[1]+=1 if p[2]=="1" else 0
            if p[2]=="1" and p[3] and name not in renamed:
                renamed[name] = strip(p[3])
    avail = {}
    for name, (n_over, n_dep) in dep_all.items():
        rec = {}
        if name in intro: rec["introduced_macos"] = f"{intro[name][0]}.{intro[name][1]}"
        # deprecated only if EVERY public overload is deprecated (avoids flagging APIs that
        # merely have one deprecated overload, e.g. foregroundStyle)
        rec["deprecated"] = (n_dep == n_over and n_over > 0)
        if rec["deprecated"] and name in renamed: rec["renamed"] = renamed[name]
        avail[name] = rec
    # curated replacements — the symbol graph leaves `renamed` null for most deprecations, but the
    # replacement is well-known. Fill them so `deprecated <api>` is actionable.
    REPLACEMENTS = {
        "foregroundColor": ("foregroundStyle", None),
        "navigationBarTitle": ("navigationTitle", None),
        "NavigationView": ("NavigationStack", "use NavigationStack for single-column, NavigationSplitView for sidebar+detail"),
        "navigationBarItems": ("toolbar", None),
        "actionSheet": ("confirmationDialog", None),
        "Alert": ("alert", "use the .alert(_:isPresented:) modifier"),
        "alert(isPresented:content:)": ("alert", None),
        "disableAutocorrection": ("autocorrectionDisabled", None),
        "edgesIgnoringSafeArea": ("ignoresSafeArea", None),
        "tabItem": ("Tab", "use Tab(_:systemImage:) inside TabView(selection:)"),
        "accentColor": ("tint", None),
        "colorMultiply": ("foregroundStyle", None),
        "autocapitalization": ("textInputAutocapitalization", None),
        "contextMenu(menuItems:)": ("contextMenu", None),
        "presentationMode": ("dismiss", "use @Environment(\\.dismiss) and @Environment(\\.isPresented)"),
        "menuButton": ("Menu", None),
        "borderlessButton": ("borderless", "use .buttonStyle(.borderless)"),
    }
    for name, (rep, note) in REPLACEMENTS.items():
        e = avail.setdefault(name, {})
        e["deprecated"] = True; e["renamed"] = rep
        if note: e["note"] = note
    # symbol-graph flags a deprecated overload for some names that are actually the MODERN API — un-flag them
    NOT_DEPRECATED = {"dismiss", "isPresented"}
    for n in NOT_DEPRECATED:
        if n in avail: avail[n]["deprecated"] = False; avail[n].pop("renamed", None)
    cat = json.load(open(CAT))
    cat["availability"] = avail
    json.dump(cat, open(CAT,"w"), indent=2)
    n_dep = sum(1 for v in avail.values() if v.get("deprecated"))
    print(f"merged availability for {len(avail)} symbols ({n_dep} fully-deprecated) into sdk_catalog.json")
    for probe in ("foregroundColor","navigationBarTitle","searchable","padding","actionSheet"):
        if probe in avail: print(f"  {probe}: {avail[probe]}")

if __name__ == "__main__":
    main()
