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

    /// All known symbol names (for search / suggestions), tagged by dimension.
    func allSymbols() -> [(String, String)] {
        var out: [(String, String)] = []
        for dim in Self.dims { for k in obj("\(dim).json").keys { out.append((k, dim)) } }
        return out
    }

    func suggest(_ q: String, limit: Int = 5) -> [String] {
        let lq = q.lowercased()
        let names = allSymbols().map { $0.0 }
        let subs = names.filter { $0.lowercased().contains(lq) }
        if !subs.isEmpty {
            return Array(subs.sorted { $0.count < $1.count }.prefix(limit))
        }
        // fall back to nearest by simple prefix/contains of query fragments
        return Array(names.sorted { lev($0.lowercased(), lq) < lev($1.lowercased(), lq) }.prefix(limit))
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
