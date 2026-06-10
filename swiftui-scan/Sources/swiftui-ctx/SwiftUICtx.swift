import Foundation
import ArgumentParser

// ============================================================================
// swiftui-ctx — query real-world SwiftUI usage (1,857 production macOS apps).
// The "practice" layer; pair with sosumi.ai (the "spec"/official docs) it links to.
// Agent contract: --json envelope, stderr-only logs, semantic exit codes, next_actions.
// ============================================================================

@main
struct SwiftUICtx: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftui-ctx",
        abstract: "Real-world SwiftUI usage from 1,857 production macOS apps — context for AI agents.",
        discussion: """
        Every result is ranked by production quality (author authority + stars + modernity) and ends
        with `next_actions` you can run to drill in. Use --json for the machine envelope.
        Exit codes: 0 ok · 2 usage · 3 not-found · 4 network · 5 no-catalog.
        """,
        version: "1.0.2",
        subcommands: [Lookup.self, Search.self, Examples.self, FileCmd.self,
                      Recipe.self, Recipes.self, Repo.self, Deprecated.self, Stats.self,
                      Bridges.self, Settings.self, Conformances.self, Rankings.self, Insights.self,
                      ValueBuilders.self, Doctor.self],
        defaultSubcommand: Lookup.self)
}

// Health check: confirms the catalog loads and reports what's available.
struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check the catalog, version, and environment.")
    @OptionGroup var common: Common
    func run() {
        let cat = loadCatalog(common)        // exits 5 with a clear error if the catalog is missing
        let idx = cat.index
        let result: [String: Any] = ["version": "1.0.2", "ok": true,
            "catalog_dir": cat.dir.path, "repos": idx.i("repos_analyzed") ?? 0,
            "sdk": idx.s("sdk") ?? "?", "dimensions": idx.dict("dimension_sizes")]
        emit(result: result, next: [NextAction(cmd: "swiftui-ctx lookup searchable", why: "try a real query")],
             json: common.json) {
            "swiftui-ctx 1.0.2 — OK\n  catalog: \(cat.dir.path)\n  corpus: \(idx.i("repos_analyzed") ?? 0) repos · \(idx.s("sdk") ?? "?")"
        }
    }
}

struct Common: ParsableArguments {
    @Flag(name: .long, help: "Emit the stable JSON envelope on stdout.") var json = false
    @Option(name: .long, help: "Path to the catalog/ directory.") var catalog: String?
    @Option(name: .long, help: "Max results.") var limit: Int = 6
    @Option(name: .long, help: "Filter by platform: macos|any.") var platform: String = "macos"
    @Flag(name: .long, help: "Catalog only; do not fetch live source.") var offline = false
}

// Normalize an API token the way developers/LLMs write it: `@State`→State, `.frame`→frame,
// `frame(width:height:)`→frame, `Color.red`→keep last? (we keep as-is for member chains).
func normalizeAPI(_ s: String) -> String {
    var n = s.trimmingCharacters(in: .whitespaces)
    while n.first == "@" || n.first == "." { n.removeFirst() }
    if let p = n.firstIndex(of: "(") { n = String(n[..<p]) }
    return n
}

// ---- shared helpers ----
func loadCatalog(_ c: Common) -> Catalog {
    do { return try Catalog(dir: c.catalog) }
    catch let e as CtxError { die(e, json: c.json) }
    catch { die(CtxError(cls: "no_data", code: "NO_CATALOG", message: "\(error)",
                         retryable: false, suggestion: nil, exit: .noData), json: c.json) }
}

func sosumiDoc(_ dim: String, _ name: String) -> String {
    let lname = name.lowercased()
    switch dim {
    case "types", "valueBuilders", "macros": return "https://sosumi.ai/documentation/swiftui/\(lname)"
    case "propertyWrappers": return "https://sosumi.ai/documentation/swiftui/\(lname)"
    case "environmentKeys": return "https://sosumi.ai/documentation/swiftui/environmentvalues/\(lname)"
    default: return "https://sosumi.ai/documentation/swiftui/view/\(lname)"   // modifiers, styleValues
    }
}

func examplesFiltered(_ entry: [String: Any], platform: String, shape: String?, repo: String?) -> [[String: Any]] {
    var exs = (entry.arr("examples") as? [[String: Any]]) ?? entry.arr("examples").compactMap { $0 as? [String: Any] }
    if platform == "macos" {
        let mac = exs.filter { ($0.dict("provenance").s("platform")) == "macos" }
        if !mac.isEmpty { exs = mac }   // fall back to all if none are macOS
    }
    if let sh = shape { exs = exs.filter { $0.s("shape") == sh } }
    if let rp = repo { exs = exs.filter { ($0.s("repo")?.lowercased()) == rp.lowercased() } }
    return exs
}

func consensus(_ entry: [String: Any]) -> [[String: Any]] {
    let shapes = (entry.arr("arg_shapes") as? [[String: Any]]) ?? entry.arr("arg_shapes").compactMap { $0 as? [String: Any] }
    let total = shapes.reduce(0) { $0 + ($1.i("uses") ?? 0) }
    guard total > 0 else { return [] }
    return shapes.prefix(6).map { ["shape": $0.s("shape") ?? "", "pct": Int(round(100.0 * Double($0.i("uses") ?? 0) / Double(total)))] }
}

func exampleBrief(_ e: [String: Any]) -> [String: Any] {
    let p = e.dict("provenance")
    return ["id": e.s("id") ?? "", "repo": e.s("repo") ?? "", "permalink": e.s("permalink") ?? "",
            "src": e.s("src") ?? "", "shape": e.s("shape") ?? NSNull(),
            "stars": p.i("stars") ?? 0, "author_authority": p.i("author_authority") ?? 0,
            "min_macos": p.s("min_macos") ?? NSNull(), "score": p["score"] ?? 0]
}

// ============================================================================
// lookup — the context pack for one API
// ============================================================================
struct Lookup: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "How an API is used in production (consensus + ranked examples).")
    @OptionGroup var common: Common
    @Argument(help: "A SwiftUI symbol, e.g. searchable, NavigationSplitView, AppStorage.") var api: String

    func run() {
        let cat = loadCatalog(common)
        var api = normalizeAPI(self.api)
        if api.isEmpty {
            die(CtxError(cls: "usage", code: "EMPTY_QUERY", message: "API name is empty",
                retryable: false, suggestion: "e.g. swiftui-ctx lookup searchable", exit: .usage), json: common.json)
        }
        guard let found = cat.find(api) else {
            // soft redirect: protocols/patterns (e.g. NSViewRepresentable) live in recipes, not dimensions
            if let rec = cat.recipes().first(where: { (($0["apis"] as? [String]) ?? []).contains(api) }),
               let rn = rec.s("name") {
                emit(result: ["api": api, "redirect": "recipe", "recipe": rn,
                              "note": "\(api) is a conformance/pattern — see the recipe"],
                     next: [NextAction(cmd: "swiftui-ctx recipe \(rn)", why: "the \(api) pattern + real examples")],
                     json: common.json) { "ℹ️ \(api) is a pattern, not a single API → swiftui-ctx recipe \(rn)" }
                return
            }
            // AppKit/UIKit name (NSWindow…, UIView…) → out of scope; we only index SwiftUI.
            if api.range(of: "^(NS|UI)[A-Z]", options: .regularExpression) != nil {
                var next: [NextAction] = []
                if cat.recipe("nsview-bridge") != nil {
                    next.append(NextAction(cmd: "swiftui-ctx recipe nsview-bridge", why: "wrap an AppKit/UIKit view in SwiftUI"))
                }
                next.append(NextAction(cmd: "swiftui-ctx search \(api)", why: "find related SwiftUI APIs"))
                emit(result: ["api": api, "out_of_scope": "appkit_uikit",
                              "note": "\(api) looks like an AppKit/UIKit type — swiftui-ctx indexes SwiftUI only"],
                     next: next, json: common.json) {
                    "ℹ️ \(api) looks like an AppKit/UIKit API — swiftui-ctx indexes SwiftUI only.\n  For bridging an AppKit view into SwiftUI, see: swiftui-ctx recipe nsview-bridge"
                }
                return
            }
            // intent / multi-word resolution (aliases, substring, recipes) before giving up.
            let r = cat.resolve(self.api)
            if !r.apis.isEmpty || !r.recipes.isEmpty {
                let apis = Array(r.apis.prefix(common.limit))
                var next = apis.prefix(3).map { NextAction(cmd: "swiftui-ctx lookup \($0)", why: "production usage") }
                if let rn = r.recipes.first { next.append(NextAction(cmd: "swiftui-ctx recipe \(rn)", why: "the full pattern")) }
                emit(result: ["api": api, "redirect": "search", "apis": apis, "recipes": r.recipes,
                              "note": "no single API named '\(api)' — closest matches by intent"],
                     next: next, json: common.json) {
                    var s = "ℹ️ no single API named '\(api)' — closest by intent:\n  apis: " + apis.joined(separator: ", ")
                    if !r.recipes.isEmpty { s += "\n  recipes: " + r.recipes.joined(separator: ", ") }
                    return s
                }
                return
            }
            let sug = cat.suggest(api)
            die(CtxError(cls: "not_found", code: "UNKNOWN_API",
                message: "no usage found for '\(api)'", retryable: false,
                suggestion: sug.isEmpty ? "run `swiftui-ctx search \(api)`" : "did you mean: \(sug.joined(separator: ", "))?",
                exit: .notFound), json: common.json)
        }
        api = found.name                 // canonical casing (handles `navigationstack` → NavigationStack)
        let dim = found.dim, entry = found.entry
        let av = entry.dict("availability")
        let exs = examplesFiltered(entry, platform: common.platform, shape: nil, repo: nil)
        // recommended = top-scored; diverse = next distinct shapes
        let recommended = exs.first.map(exampleBrief)
        var seen = Set([exs.first?.s("shape") ?? ""]); var diverse: [[String: Any]] = []
        for e in exs.dropFirst() where !seen.contains(e.s("shape") ?? "") {
            seen.insert(e.s("shape") ?? ""); diverse.append(exampleBrief(e)); if diverse.count >= 3 { break }
        }
        // lift-based co-occurrence (stored per symbol): APIs used disproportionately with this one
        let coSyms = entry.arr("co_occurs_with").compactMap { ($0 as? [String: Any])?.s("sym") }
        // matching recipe(s)
        let recs = cat.recipes().filter { (($0["apis"] as? [String]) ?? []).contains(api) }.compactMap { $0.s("name") }

        var result: [String: Any] = [
            "api": api, "kind": dim, "repo_count": entry.i("repo_count") ?? 0,
            "total_uses": entry.i("total_uses") ?? 0,
            "introduced_macos": av.s("introduced_macos") ?? NSNull(),
            "deprecated": av["deprecated"] as? Bool ?? false,
            "doc": sosumiDoc(dim, api),
            "consensus": consensus(entry),
            "recommended": recommended ?? NSNull(),
            "diverse": diverse,
            "co_occurs_with": Array(coSyms),
            "recipes": recs,
            "low_corpus": entry["low_corpus"] as? Bool ?? false,
        ]
        if av["deprecated"] as? Bool == true { result["replacement"] = av.s("renamed") ?? NSNull() }

        var next: [NextAction] = []
        if let r = recommended, let id = r["id"] as? String, !id.isEmpty {
            next.append(NextAction(cmd: "swiftui-ctx file \(id)", why: "see the full enclosing view"))
        }
        next.append(NextAction(cmd: "swiftui-ctx examples \(api) --limit 12", why: "more real call sites"))
        if let rn = recs.first { next.append(NextAction(cmd: "swiftui-ctx recipe \(rn)", why: "the multi-API pattern")) }
        if av["deprecated"] as? Bool == true, let rep = av.s("renamed") {
            next.append(NextAction(cmd: "swiftui-ctx lookup \(rep)", why: "use the modern replacement"))
        }

        emit(result: result, next: next, json: common.json) {
            var s = "# .\(api)  (\(dim))\n"
            s += "used in \(entry.i("repo_count") ?? 0) repos · \(entry.i("total_uses") ?? 0) uses"
            if let iv = av.s("introduced_macos") { s += " · macOS \(iv)+" }
            if av["deprecated"] as? Bool == true { s += "  ⚠️ DEPRECATED → .\(av.s("renamed") ?? "?")" }
            if entry["low_corpus"] as? Bool == true { s += "\n⚠️ low corpus (\(entry.i("repo_count") ?? 0) repos) — cross-check the doc below" }
            s += "\ndoc: \(sosumiDoc(dim, api))\n"
            let cons = consensus(entry)
            if !cons.isEmpty {
                s += "\nconsensus: " + cons.map { "\($0["shape"] as? String ?? "") \($0["pct"] as? Int ?? 0)%" }.joined(separator: " · ")
            } else if dim == "propertyWrappers" || dim == "macros" {
                s += "\nconsensus: — (used as a bare attribute; no argument forms)"
            }
            if let r = recommended {
                s += "\n\n▶ recommended (\(r["repo"] as? String ?? ""), \(r["stars"] as? Int ?? 0)★):\n  \(r["src"] as? String ?? "")\n  \(r["permalink"] as? String ?? "")"
            }
            for d in diverse {
                s += "\n\n• \(d["repo"] as? String ?? ""):\n  \(d["src"] as? String ?? "")"
            }
            if !coSyms.isEmpty { s += "\n\noften used with: " + coSyms.joined(separator: ", ") }
            return s
        }
    }
}

// ============================================================================
// examples — paginated raw call sites with filters
// ============================================================================
struct Examples: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Ranked real call sites for an API (filterable, paginated).")
    @OptionGroup var common: Common
    @Argument var api: String
    @Option(name: .long, help: "Filter to a specific arg-shape, e.g. \"(text:)\".") var shape: String?
    @Option(name: .long, help: "Filter to a specific repo (owner/name).") var repo: String?
    @Option(name: .long, help: "Page (1-based).") var page: Int = 1

    func run() {
        let cat = loadCatalog(common)
        let api = normalizeAPI(self.api)
        guard let (_, entry) = cat.symbol(api) else {
            die(CtxError(cls: "not_found", code: "UNKNOWN_API", message: "no usage found for '\(api)'",
                retryable: false, suggestion: "run `swiftui-ctx search \(api)`", exit: .notFound), json: common.json)
        }
        let all = examplesFiltered(entry, platform: common.platform, shape: shape, repo: repo)
        let start = max(0, (page - 1) * common.limit)
        let pageItems = Array(all.dropFirst(start).prefix(common.limit)).map(exampleBrief)
        var result: [String: Any] = ["api": api, "matched_in_sample": all.count, "page": page,
                                     "limit": common.limit, "platform": common.platform, "examples": pageItems]
        // examples are a curated ≤25/api quality-ranked sample — explain the gap vs lookup's consensus %.
        var note = "examples are a curated, quality-ranked sample (≤25 per API) of \(entry.i("total_uses") ?? 0) total uses; for frequency see `swiftui-ctx lookup \(api)` consensus."
        if common.platform == "macos" { note += " (macOS only; pass --platform any for iOS/library examples.)" }
        result["note"] = note
        var next: [NextAction] = []
        if let f = pageItems.first, let id = f["id"] as? String {
            next.append(NextAction(cmd: "swiftui-ctx file \(id)", why: "expand the first example"))
        }
        if start + common.limit < all.count {
            next.append(NextAction(cmd: "swiftui-ctx examples \(api) --page \(page+1)", why: "next page"))
        }
        emit(result: result, next: next, json: common.json) {
            var s = "# examples of .\(api)  (\(all.count) in curated sample, page \(page))\n\(note)\n"
            for e in pageItems {
                s += "\n[\(e["id"] as? String ?? "")] \(e["repo"] as? String ?? "") (\(e["stars"] as? Int ?? 0)★)\n  \(e["src"] as? String ?? "")\n  \(e["permalink"] as? String ?? "")"
            }
            return s
        }
    }
}

// ============================================================================
// file — fetch the real source live and show a syntax-accurate span
// ============================================================================
struct FileCmd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "file",
        abstract: "Fetch the real source for an example id or permalink (enclosing view / chain / whole file).")
    @OptionGroup var common: Common
    @Argument(help: "An example id (ex_…) or a GitHub blob permalink.") var target: String
    @Flag(name: .long, help: "Tightest useful span: statement/chain/decl that fits (default).") var smart = false
    @Flag(name: .long, help: "Show the full enclosing declaration (e.g. whole var body).") var decl = false
    @Flag(name: .long, help: "Show the modifier chain.") var chain = false
    @Flag(name: .long, help: "Show the whole file.") var full = false

    func run() {
        let cat = loadCatalog(common)
        // resolve to permalink + cached src
        var permalink = target; var storedSrc = ""
        if !target.hasPrefix("http") {
            guard let rec = cat.exampleIndex()[target] as? [String: Any], let pl = rec.s("permalink") else {
                die(CtxError(cls: "not_found", code: "UNKNOWN_ID", message: "no example with id '\(target)'",
                    retryable: false, suggestion: "ids come from `lookup`/`examples` output", exit: .notFound), json: common.json)
            }
            permalink = pl; storedSrc = rec.s("src") ?? ""
        }
        guard let parts = parsePermalink(permalink) else {
            die(CtxError(cls: "usage", code: "BAD_PERMALINK", message: "could not parse permalink: \(permalink)",
                retryable: false, suggestion: nil, exit: .usage), json: common.json)
        }
        let mode: SpanMode = full ? .full : (chain ? .chain : (decl ? .decl : .smart))
        if common.offline {
            let result: [String: Any] = ["permalink": permalink, "mode": "offline-line", "code": storedSrc]
            emit(result: result, next: [], json: common.json) { "\(permalink)\n\n\(storedSrc)" }
            return
        }
        do {
            let source = try fetchFile(parts)
            let range = extractSpan(source, line: parts.line, mode: mode)
            let code = sliceLines(source, range)
            let result: [String: Any] = ["permalink": permalink, "mode": "\(mode)",
                "range": ["start": range.0, "end": range.1], "code": code]
            var next: [NextAction] = []
            if mode != .full { next.append(NextAction(cmd: "swiftui-ctx file \(target) --full", why: "the whole file")) }
            if mode != .chain { next.append(NextAction(cmd: "swiftui-ctx file \(target) --chain", why: "just the modifier chain")) }
            emit(result: result, next: next, json: common.json) {
                "\(permalink)  (lines \(range.0)-\(range.1))\n\n\(code)"
            }
        } catch let e as CtxError { die(e, json: common.json) }
        catch { die(CtxError(cls: "transient", code: "FETCH_FAILED", message: "\(error)",
            retryable: true, suggestion: "retry or use --offline", exit: .network), json: common.json) }
    }
}

// ============================================================================
// recipe / recipes — multi-API production patterns
// ============================================================================
struct Recipes: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List the production patterns (recipes).")
    @OptionGroup var common: Common
    func run() {
        let cat = loadCatalog(common)
        let recs = cat.recipes().map { r -> [String: Any] in
            ["name": r.s("name") ?? "", "description": r.s("description") ?? "",
             "apis": (r["apis"] as? [String]) ?? [], "repos": r.i("repos") ?? 0] }
        emit(result: ["count": recs.count, "recipes": recs],
             next: recs.first.map { [NextAction(cmd: "swiftui-ctx recipe \($0["name"] as? String ?? "")", why: "open a recipe")] } ?? [],
             json: common.json) {
            recs.map { "• \($0["name"] as? String ?? "")  — \($0["description"] as? String ?? "")" }.joined(separator: "\n")
        }
    }
}

struct Recipe: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "A production pattern: template skeleton + real examples.")
    @OptionGroup var common: Common
    @Argument var name: String
    func run() {
        let cat = loadCatalog(common)
        guard let r = cat.recipe(name) else {
            let names = cat.recipes().compactMap { $0.s("name") }
            die(CtxError(cls: "not_found", code: "UNKNOWN_RECIPE", message: "no recipe '\(name)'",
                retryable: false, suggestion: "available: \(names.joined(separator: ", "))", exit: .notFound), json: common.json)
        }
        let apis = (r["apis"] as? [String]) ?? []
        var next = apis.prefix(3).map { NextAction(cmd: "swiftui-ctx lookup \($0)", why: "usage of \($0)") }
        if let ex = r.arr("examples").first as? [String: Any], let tgt = ex.s("id") ?? ex.s("permalink") {
            next.insert(NextAction(cmd: "swiftui-ctx file \(tgt)", why: "open the first real example"), at: 0)
        }
        emit(result: r, next: next, json: common.json) {
            var s = "# recipe: \(r.s("name") ?? "")\n\(r.s("description") ?? "")\n"
            s += "\nAPIs: \(apis.joined(separator: ", "))\n\nTemplate:\n\(r.s("template") ?? "")\n\nReal examples:"
            for e in (r.arr("examples").compactMap { $0 as? [String: Any] }).prefix(6) {
                s += "\n  • \(e.s("repo") ?? "") — \(e.s("permalink") ?? "")"
            }
            return s
        }
    }
}

// ============================================================================
// repo — a single repo's production profile
// ============================================================================
struct Repo: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "A repo's SwiftUI fingerprint, components, modernity, authority.")
    @OptionGroup var common: Common
    @Argument(help: "owner/name") var full: String
    func run() {
        let cat = loadCatalog(common)
        guard let p = cat.byRepo(full) else {
            die(CtxError(cls: "not_found", code: "UNKNOWN_REPO", message: "repo '\(full)' not in corpus",
                retryable: false, suggestion: "only the 1,857 analyzed repos are available", exit: .notFound), json: common.json)
        }
        emit(result: p, next: [], json: common.json) {
            let counts = p.dict("counts")
            var s = "# \(full)  (\(p.i("stars") ?? 0)★, \(p.s("platform") ?? "?"))\n"
            s += "author_authority: \(p.i("author_authority") ?? 0) · min macOS: \(p.s("min_macos_inferred") ?? "?") · custom components: \(p.i("custom_components") ?? 0)\n"
            s += "unique APIs: " + counts.keys.sorted().map { "\($0)=\(counts.i($0) ?? 0)" }.joined(separator: " ")
            let dep = (p["deprecated_apis_used"] as? [String]) ?? []
            if !dep.isEmpty { s += "\n⚠️ deprecated APIs used: \(dep.joined(separator: ", "))" }
            return s
        }
    }
}

// ============================================================================
// deprecated — anti-pattern engine (don't teach stale idioms)
// ============================================================================
struct Deprecated: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Deprecated APIs in real use + their modern replacements.")
    @OptionGroup var common: Common
    @Argument(help: "Optional: a specific API to check.") var api: String?
    func run() {
        let cat = loadCatalog(common)
        if let raw = api {
            let api = normalizeAPI(raw)
            guard let (dim, entry) = cat.symbol(api) else {
                die(CtxError(cls: "not_found", code: "UNKNOWN_API", message: "no usage of '\(api)'",
                    retryable: false, suggestion: "run `swiftui-ctx search \(api)`", exit: .notFound), json: common.json)
            }
            let av = entry.dict("availability")
            let dep = av["deprecated"] as? Bool ?? false
            let rep = av.s("renamed"); let note = av.s("note")
            var result: [String: Any] = ["api": api, "deprecated": dep, "replacement": rep ?? NSNull(),
                                         "note": note ?? NSNull(), "doc": sosumiDoc(dim, api)]
            var next: [NextAction] = []
            if let rep = rep {
                result["migrate_to"] = rep
                next.append(NextAction(cmd: "swiftui-ctx lookup \(rep)", why: "real usage of the replacement"))
            } else {
                next.append(NextAction(cmd: "swiftui-ctx lookup \(api)", why: "see how it's used (no known replacement)"))
            }
            emit(result: result, next: next, json: common.json) {
                var s = dep ? "⚠️ .\(api) is DEPRECATED" + (rep != nil ? " → use .\(rep!)" : "")
                            : ".\(api) is not deprecated."
                if let note = note { s += "\n  note: \(note)" }
                return s
            }
        } else {
            let list = cat.deprecatedUsage().prefix(common.limit).map { d -> [String: Any] in
                ["api": d.s("sym") ?? "", "replacement": d.s("renamed") ?? NSNull(), "repos": d.i("repos") ?? 0] }
            emit(result: ["deprecated_in_use": list],
                 next: list.first.map { [NextAction(cmd: "swiftui-ctx deprecated \($0["api"] as? String ?? "")", why: "migration detail")] } ?? [],
                 json: common.json) {
                "Deprecated APIs still used in production:\n" + list.map { d in
                    let rep = d["replacement"] as? String
                    let arrow = (rep == nil || rep!.isEmpty) ? "(no known replacement)" : "→ .\(rep!)"
                    return "  ⚠️ .\(d["api"] as? String ?? "") \(arrow)  (\(d["repos"] as? Int ?? 0) repos)"
                }.joined(separator: "\n")
            }
        }
    }
}

// ============================================================================
// search — find APIs / recipes by keyword
// ============================================================================
struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Find APIs and recipes by keyword.")
    @OptionGroup var common: Common
    @Argument(help: "A keyword or intent fragment.") var query: String
    func run() {
        let cat = loadCatalog(common)
        let r = cat.resolve(query)
        let apis = Array(r.apis.prefix(common.limit))
        let recs = r.recipes
        let result: [String: Any] = ["query": query, "apis": apis, "recipes": recs,
                                     "matched_intent": r.matchedIntent]
        var next = apis.prefix(3).map { NextAction(cmd: "swiftui-ctx lookup \($0)", why: "production usage") }
        if let r = recs.first { next.append(NextAction(cmd: "swiftui-ctx recipe \(r)", why: "the full pattern")) }
        emit(result: result, next: next, json: common.json) {
            var s = "matches for '\(query)':\n  apis: " + apis.joined(separator: ", ")
            if !recs.isEmpty { s += "\n  recipes: " + recs.joined(separator: ", ") }
            return s
        }
    }
}

// ============================================================================
// stats — corpus overview
// ============================================================================
struct Stats: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Corpus overview and coverage.")
    @OptionGroup var common: Common
    func run() {
        let cat = loadCatalog(common)
        let idx = cat.index
        let modern = cat.obj("insights.json").dict("modern_stack_adoption_pct")
        let result: [String: Any] = ["repos": idx.i("repos_analyzed") ?? 0,
            "sdk": idx.s("sdk") ?? "", "dimension_sizes": idx.dict("dimension_sizes"),
            "custom_components": idx.i("custom_components") ?? 0,
            "modern_stack": modern]
        emit(result: result, next: [NextAction(cmd: "swiftui-ctx recipes", why: "browse production patterns")],
             json: common.json) {
            "swiftui-ctx — \(idx.i("repos_analyzed") ?? 0) repos · \(idx.s("sdk") ?? "")\n"
            + "dimensions: \(idx.dict("dimension_sizes"))\n"
            + "custom components: \(idx.i("custom_components") ?? 0)"
        }
    }
}
