import Foundation

// Loads the catalog/ JSON shards (the data contract produced by scripts/05_catalog.py).
final class Catalog {
    let dir: URL
    private var cache: [String: Any] = [:]
    // lookup precedence: wrappers/macros BEFORE types so `Observable`/`State`/`Binding` resolve to the
    // SwiftUI wrapper, not a same-named type construction (e.g. Combine's Observable()).
    static let dims = ["modifiers","propertyWrappers","macros","valueBuilders","styleValues",
                       "types","environmentKeys"]

    init(dir: String?) throws {
        let fm = FileManager.default
        let raw: [String?] = [
            dir,
            ProcessInfo.processInfo.environment["SWIFTUI_CTX_CATALOG"],
            fm.currentDirectoryPath + "/catalog",
            // package-relative fallback: <repo>/catalog next to swiftui-scan/
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
                .appendingPathComponent("../../../catalog").standardized.path,
        ]
        let candidates: [String] = raw.compactMap { $0 }
        guard let found = candidates.first(where: { (p: String) in
            fm.fileExists(atPath: (p as NSString).appendingPathComponent("index.json"))
        }) else {
            throw CtxError(cls: "no_data", code: "NO_CATALOG",
                message: "catalog/ not found (looked in: \(candidates.joined(separator: ", ")))",
                retryable: false, suggestion: "pass --catalog <dir> or set SWIFTUI_CTX_CATALOG", exit: .noData)
        }
        self.dir = URL(fileURLWithPath: found, isDirectory: true)
    }

    func json(_ file: String) -> Any? {
        if let c = cache[file] { return c }
        guard let d = try? Data(contentsOf: dir.appendingPathComponent(file)),
              let o = try? JSONSerialization.jsonObject(with: d) else { return nil }
        cache[file] = o; return o
    }
    func obj(_ file: String) -> [String: Any] { (json(file) as? [String: Any]) ?? [:] }
    var index: [String: Any] { obj("index.json") }

    /// Find a symbol across all dimension shards. Returns (dimension, entry).
    func symbol(_ name: String) -> (String, [String: Any])? {
        for dim in Self.dims {
            if let e = obj("\(dim).json")[name] as? [String: Any] { return (dim, e) }
        }
        return nil
    }

    /// Resolve a symbol exact-first, then case-insensitively. Returns the CANONICAL name
    /// alongside its dimension + entry, so callers render the real casing (fixes `navigationstack`).
    func find(_ name: String) -> (name: String, dim: String, entry: [String: Any])? {
        for dim in Self.dims {
            if let e = obj("\(dim).json")[name] as? [String: Any] { return (name, dim, e) }
        }
        let lname = name.lowercased()
        for dim in Self.dims {
            for (k, v) in obj("\(dim).json") where k.lowercased() == lname {
                if let e = v as? [String: Any] { return (k, dim, e) }
            }
        }
        return nil
    }

    /// All known symbol names (for search / suggestions), tagged by dimension.
    func allSymbols() -> [(String, String)] {
        var out: [(String, String)] = []
        for dim in Self.dims { for k in obj("\(dim).json").keys { out.append((k, dim)) } }
        return out
    }

    func suggest(_ q: String, limit: Int = 5) -> [String] {
        let names = allSymbols().map { $0.0 }
        let tokens = q.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 2 }
        // single-token (or no letters): substring, else nearest by edit distance on that token.
        if tokens.count <= 1 {
            let lq = tokens.first ?? q.lowercased()
            let subs = names.filter { $0.lowercased().contains(lq) }
            if !subs.isEmpty { return Array(subs.sorted { $0.count < $1.count }.prefix(limit)) }
            return Array(names.sorted { lev($0.lowercased(), lq) < lev($1.lowercased(), lq) }.prefix(limit))
        }
        // multi-word: rank by #tokens the name contains (desc), then shortest — never Levenshtein
        // on the joined string (that produced garbage like "sheet presentation" → "hueRotation").
        func score(_ name: String) -> Int { let l = name.lowercased(); return tokens.filter { l.contains($0) }.count }
        let scored = names.map { ($0, score($0)) }.filter { $0.1 > 0 }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.count < $1.0.count }.map { $0.0 }
        if !scored.isEmpty { return Array(scored.prefix(limit)) }
        let longest = tokens.max(by: { $0.count < $1.count }) ?? q.lowercased()
        return Array(names.sorted { lev($0.lowercased(), longest) < lev($1.lowercased(), longest) }.prefix(limit))
    }

    /// Intent resolution shared by `search` and the `lookup` miss-cascade: curated aliases
    /// (substring / shared significant word / direct apis membership) + substring symbol hits +
    /// recipe name/description hits. `matchedIntent` is true when a curated alias fired.
    func resolve(_ query: String) -> (apis: [String], recipes: [String], matchedIntent: Bool) {
        let q = query.lowercased()
        let qWords = Set(q.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 4 })
        var aliasApis: [String] = [], aliasRecs: [String] = []
        for (kw, v) in aliases() {
            guard let d = v as? [String: Any] else { continue }
            let apis = (d["apis"] as? [String]) ?? []
            let kwWords = Set(kw.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 4 })
            let hit = q.contains(kw) || kw.contains(q) || !qWords.isDisjoint(with: kwWords)
                || apis.contains(where: { $0.lowercased() == q })   // e.g. `withAnimation` → animation intent
            guard hit else { continue }
            aliasApis += apis; aliasRecs += (d["recipes"] as? [String]) ?? []
        }
        let subs = allSymbols().filter { $0.0.lowercased().contains(q) }
            .sorted { $0.0.count < $1.0.count }.map { $0.0 }
        let recHits = recipes().filter {
            ($0.s("name")?.lowercased().contains(q) ?? false) || ($0.s("description")?.lowercased().contains(q) ?? false)
        }.compactMap { $0.s("name") }
        func uniq(_ xs: [String]) -> [String] { var seen = Set<String>(); return xs.filter { seen.insert($0).inserted } }
        return (uniq(aliasApis + subs), uniq(aliasRecs + recHits), !aliasApis.isEmpty)
    }

    func aliases() -> [String: Any] { obj("aliases.json") }
    func recipes() -> [[String: Any]] { (obj("recipes.json")["recipes"] as? [[String: Any]]) ?? [] }
    func recipe(_ name: String) -> [String: Any]? {
        recipes().first { ($0["name"] as? String)?.lowercased() == name.lowercased() }
    }
    func byRepo(_ full: String) -> [String: Any]? {
        json("by_repo/\(full.replacingOccurrences(of: "/", with: "__")).json") as? [String: Any]
    }
    func exampleIndex() -> [String: Any] { obj("examples_index.json") }
    func deprecatedUsage() -> [[String: Any]] {
        (obj("insights.json")["deprecated_api_usage"] as? [[String: Any]]) ?? []
    }
    func coOccurrence() -> [[String: Any]] {
        (obj("insights.json")["co_occurrence"] as? [[String: Any]]) ?? []
    }
}

// tiny Levenshtein for did-you-mean
func lev(_ a: String, _ b: String) -> Int {
    let a = Array(a), b = Array(b)
    var d = Array(0...b.count)
    for i in 1...max(a.count,1) {
        var prev = d[0]; d[0] = i
        for j in 1...max(b.count,1) where b.count > 0 {
            let t = d[j]
            d[j] = a.count >= i && b.count >= j && a[i-1] == b[j-1] ? prev : min(prev, d[j], d[j-1]) + 1
            prev = t
        }
    }
    return d[b.count]
}

// dictionary helpers
extension Dictionary where Key == String, Value == Any {
    func s(_ k: String) -> String? { self[k] as? String }
    func i(_ k: String) -> Int? { (self[k] as? Int) ?? (self[k] as? NSNumber)?.intValue }
    func arr(_ k: String) -> [Any] { (self[k] as? [Any]) ?? [] }
    func dict(_ k: String) -> [String: Any] { (self[k] as? [String: Any]) ?? [:] }
}
