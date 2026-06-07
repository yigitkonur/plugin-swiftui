#!/usr/bin/env python3
"""Stage 8 — Build catalog/recipes.json: multi-API production patterns an agent can request whole.

Two sources:
  1. Curated recipes (canonical templates) whose presence we verify against the corpus and to which
     we attach real top examples (by the score already baked into the shards).
  2. Mined "bridge" + "settings" template recipes from catalog/{bridges,settings}.json.

Each recipe: {name, kind, apis:[...], description, template (code skeleton), repos (count), examples:[ex ids]}.
"""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, "..")
CAT = os.path.join(ROOT, "catalog")

def load(name):
    try: return json.load(open(os.path.join(CAT, name)))
    except Exception: return {}

# Curated recipes: api list + a canonical skeleton. We resolve real examples from the shards.
CURATED = [
 {"name":"menubar-app","apis":["MenuBarExtra","menuBarExtraStyle","Settings"],"dim":"types","anchor":"MenuBarExtra",
  "description":"A menu-bar (status item) macOS app with a Settings window.",
  "template":'@main struct MyApp: App {\n  var body: some Scene {\n    MenuBarExtra("Title", systemImage: "star") {\n      ContentView()\n    }.menuBarExtraStyle(.window)\n    Settings { SettingsView() }\n  }\n}'},
 {"name":"master-detail","apis":["NavigationSplitView","List","navigationDestination"],"dim":"types","anchor":"NavigationSplitView",
  "description":"Sidebar + detail navigation (the macOS standard).",
  "template":'NavigationSplitView {\n  List(items, selection: $selection) { item in\n    NavigationLink(item.name, value: item)\n  }\n} detail: {\n  DetailView(selection)\n}'},
 {"name":"searchable-list","apis":["searchable","searchScopes"],"dim":"modifiers","anchor":"searchable",
  "description":"A list with a search field (and optional scopes).",
  "template":'List(results) { Text($0.title) }\n  .searchable(text: $query)\n  // bind @State private var query = ""'},
 {"name":"settings-form","apis":["Form","Section","Toggle","Picker","LabeledContent"],"dim":"types","anchor":"Form",
  "description":"A grouped settings/preferences Form (Toggle/Picker/LabeledContent).",
  "template":'Form {\n  Section("General") {\n    Toggle("Enable", isOn: $on)\n    Picker("Theme", selection: $theme) { /* … */ }\n    LabeledContent("Version", value: appVersion)\n  }\n}.formStyle(.grouped)'},
 {"name":"observable-model","apis":["Observable","State","Bindable"],"dim":"propertyWrappers","anchor":"Observable",
  "description":"Modern Observation state: an @Observable model owned by a view.",
  "template":'@Observable final class Model { var count = 0 }\n\nstruct V: View {\n  @State private var model = Model()\n  var body: some View { Stepper("\\(model.count)", value: $model.count) }\n}'},
 {"name":"window-scene","apis":["WindowGroup","windowStyle","windowResizability","defaultSize"],"dim":"modifiers","anchor":"windowStyle",
  "description":"Custom window configuration (style/resizability/size).",
  "template":'WindowGroup { ContentView() }\n  .windowStyle(.hiddenTitleBar)\n  .windowResizability(.contentSize)\n  .defaultSize(width: 600, height: 400)'},
 {"name":"charts-bar","apis":["Chart","BarMark","chartXAxis"],"dim":"types","anchor":"BarMark",
  "description":"A Swift Charts bar chart with axis configuration.",
  "template":'Chart(data) { row in\n  BarMark(x: .value("Day", row.day), y: .value("Total", row.total))\n}\n.chartXAxis { AxisMarks() }'},
 {"name":"command-palette","apis":["searchable","keyboardShortcut","onKeyPress","focused"],"dim":"modifiers","anchor":"searchable",
  "description":"A ⌘K-style command palette / quick-open overlay: a presented panel with a search field + filtered list, opened by a keyboard shortcut and dismissed on escape.",
  "template":'.sheet(isPresented: $showPalette) {\n  VStack {\n    TextField("Search…", text: $query).focused($focused)\n    List(results) { Button($0.title) { run($0) } }\n  }.onKeyPress(.escape) { showPalette = false; return .handled }\n}\n.keyboardShortcut("k", modifiers: .command)'},
 {"name":"draggable-reorder","apis":["onMove","draggable","dropDestination","Transferable"],"dim":"modifiers","anchor":"onMove",
  "description":"Reorderable list rows. Classic: List + .onMove. Custom: .draggable/.dropDestination with a Transferable type.",
  "template":'List {\n  ForEach(items) { Text($0.name) }\n    .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }\n}'},
 {"name":"cached-async-image","apis":["AsyncImage"],"dim":"types","anchor":"AsyncImage",
  "description":"Remote image with placeholder. AsyncImage is built-in (no cache); for lists/grids real apps add a cache (custom @Observable loader or a library).",
  "template":'AsyncImage(url: url) { phase in\n  switch phase {\n  case .success(let img): img.resizable().scaledToFit()\n  case .failure: Image(systemName: "photo")\n  case .empty: ProgressView()\n  @unknown default: EmptyView()\n  }\n}'},
]

def examples_for(dim, anchor, apis, k=5):
    """Examples of `anchor`, filtered to ones whose snippet actually uses one of the recipe's APIs
    (so a charts-bar recipe never surfaces a pie-chart example)."""
    shard = load(f"{dim}.json")
    rec = shard.get(anchor)
    if not rec: return [], 0
    want = [a for a in apis if a != anchor]   # the distinguishing APIs beyond the anchor itself
    picked = []
    for e in rec.get("examples", []):
        src = e.get("src", "")
        if want and not any(a in src for a in want + [anchor]): continue
        picked.append({"id": e.get("id"), "repo": e["repo"], "permalink": e["permalink"],
                       "src": e["src"], "provenance": e.get("provenance", {})})
        if len(picked) >= k: break
    if not picked:   # fall back to unfiltered if the filter is too strict
        picked = [{"id": e.get("id"), "repo": e["repo"], "permalink": e["permalink"],
                   "src": e["src"], "provenance": e.get("provenance", {})}
                  for e in rec.get("examples", [])[:k]]
    return picked, rec.get("repo_count", 0)

def main():
    recipes = []
    for r in CURATED:
        exs, n = examples_for(r["dim"], r["anchor"], r["apis"])
        recipes.append({"name":r["name"], "kind":"pattern", "apis":r["apis"],
                        "description":r["description"], "template":r["template"],
                        "repos":n, "examples":exs})
    # bridge template recipe (NSViewRepresentable) — point at real bridges
    bridges = load("bridges.json")
    if bridges:
        recipes.append({"name":"nsview-bridge","kind":"bridge","apis":["NSViewRepresentable"],
            "description":f"Wrap an AppKit NSView in SwiftUI ({bridges.get('count',0)} real bridges across {bridges.get('repos',0)} repos).",
            "template":'struct MyView: NSViewRepresentable {\n  func makeNSView(context: Context) -> NSScrollView { … }\n  func updateNSView(_ v: NSScrollView, context: Context) { … }\n}',
            "repos":bridges.get("repos",0),
            "examples":[{"repo":b["repo"],"permalink":b["permalink"],"name":b["name"]}
                        for b in bridges.get("bridges",[])[:8]]})
    # settings screens recipe — point at richest real settings views
    settings = load("settings.json")
    if settings:
        recipes.append({"name":"settings-screen","kind":"screen","apis":["Form","TabView","Section"],
            "description":f"Full settings/preferences screens ({settings.get('count',0)} across {settings.get('repos',0)} repos). Common vocab: "
                          + ", ".join(f"{k}({v})" for k,v in settings.get("form_vocab_frequency",[])[:8]),
            "template":'struct SettingsView: View {\n  var body: some View {\n    TabView {\n      GeneralTab().tabItem { Label("General", systemImage: "gear") }\n    }.frame(width: 480, height: 320)\n  }\n}',
            "repos":settings.get("repos",0),
            "examples":[{"repo":s["repo"],"permalink":s["permalink"],"name":s["name"],"form_vocab":s["form_vocab"]}
                        for s in settings.get("screens",[])[:8]]})
    out = {"count":len(recipes), "recipes":recipes}
    json.dump(out, open(os.path.join(CAT,"recipes.json"),"w"), indent=1)
    print(f"wrote catalog/recipes.json: {len(recipes)} recipes")
    for r in recipes: print(f"  {r['name']:18} apis={r['apis']} examples={len(r['examples'])} repos={r['repos']}")

if __name__ == "__main__":
    main()
