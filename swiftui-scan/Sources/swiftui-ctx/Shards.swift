import Foundation
import ArgumentParser

// ============================================================================
// Shard commands — first-class access to the catalog shards that lookup/repo/stats
// don't fully surface: bridges · settings · conformances · rankings · insights.
// Same agent contract as the rest (--json envelope, next_actions, semantic exit codes).
// ============================================================================

// ---- bridges — real AppKit/UIKit bridges (bridges.json) ----
struct Bridges: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Real AppKit/UIKit bridges in production (NSViewRepresentable & friends).")
    @OptionGroup var common: Common
    @Argument(help: "Optional filter: a conformance kind (NSViewRepresentable…) or a name substring.") var filter: String?

    func run() {
        let cat = loadCatalog(common)
        let shard = cat.obj("bridges.json")
        let all = shard.arr("bridges").compactMap { $0 as? [String: Any] }
        let f = filter?.lowercased()
        let matched = all.filter { b in
            guard let f = f else { return true }
            let kinds = (b["conforms"] as? [String])?.map { $0.lowercased() } ?? []
            return kinds.contains(where: { $0.contains(f) }) || (b.s("name")?.lowercased().contains(f) ?? false)
        }
        var byKind: [String: Int] = [:]
        for b in matched { for k in (b["conforms"] as? [String]) ?? [] { byKind[k, default: 0] += 1 } }
        let examples = matched.prefix(common.limit).map { b -> [String: Any] in
            ["name": b.s("name") ?? "", "repo": b.s("repo") ?? "",
             "conforms": (b["conforms"] as? [String]) ?? [], "permalink": b.s("permalink") ?? ""]
        }
        let result: [String: Any] = [
            "count": shard.i("count") ?? all.count, "repos": shard.i("repos") ?? 0,
            "matched": matched.count, "by_kind": byKind, "examples": Array(examples)]
        emit(result: result,
             next: [NextAction(cmd: "swiftui-ctx recipe nsview-bridge", why: "the canonical bridge template")],
             json: common.json) {
            var s = "# bridges — \(shard.i("count") ?? all.count) total across \(shard.i("repos") ?? 0) repos"
            if f != nil { s += " · \(matched.count) match '\(filter ?? "")'" }
            s += "\nby kind: " + byKind.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            for e in examples {
                s += "\n\n• \(e["name"] as? String ?? "") — \(e["repo"] as? String ?? "")  [\((e["conforms"] as? [String] ?? []).joined(separator: ","))]\n  \(e["permalink"] as? String ?? "")"
            }
            return s
        }
    }
}

// ---- settings — production Settings/preferences screens (settings.json) ----
struct Settings: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Production Settings/preferences screens + the Form vocabulary they use.")
    @OptionGroup var common: Common

    func run() {
        let cat = loadCatalog(common)
        let shard = cat.obj("settings.json")
        let vocab = shard.arr("form_vocab_frequency").compactMap { pair -> [String: Any]? in
            guard let p = pair as? [Any], p.count >= 2, let name = p[0] as? String else { return nil }
            return ["name": name, "count": (p[1] as? Int) ?? (p[1] as? NSNumber)?.intValue ?? 0]
        }
        let screens = shard.arr("screens").compactMap { $0 as? [String: Any] }.prefix(common.limit).map { s -> [String: Any] in
            ["name": s.s("name") ?? "", "repo": s.s("repo") ?? "", "permalink": s.s("permalink") ?? ""]
        }
        let result: [String: Any] = ["count": shard.i("count") ?? 0, "repos": shard.i("repos") ?? 0,
            "form_vocab": Array(vocab.prefix(20)), "screens": Array(screens)]
        emit(result: result,
             next: [NextAction(cmd: "swiftui-ctx recipe settings-form", why: "the grouped-Form template")],
             json: common.json) {
            var s = "# settings — \(shard.i("count") ?? 0) screens across \(shard.i("repos") ?? 0) repos\n"
            s += "form vocab: " + vocab.prefix(12).map { "\($0["name"] as? String ?? "")(\($0["count"] as? Int ?? 0))" }.joined(separator: " · ")
            for sc in screens { s += "\n\n• \(sc["name"] as? String ?? "") — \(sc["repo"] as? String ?? "")\n  \(sc["permalink"] as? String ?? "")" }
            return s
        }
    }
}

// ---- conformances — custom protocol conformers (conformances.json) ----
struct Conformances: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Custom conformers of a SwiftUI protocol (ButtonStyle, Layout, Shape…).")
    @OptionGroup var common: Common
    @Argument(help: "Optional: a protocol (Layout, ButtonStyle, Shape…). Omit to list all.") var proto: String?

    func run() {
        let cat = loadCatalog(common)
        let shard = cat.obj("conformances.json")
        if let proto = proto {
            guard let key = shard.keys.first(where: { $0.lowercased() == proto.lowercased() }),
                  let entry = shard[key] as? [String: Any] else {
                let near = shard.keys.filter { $0.lowercased().contains(proto.lowercased()) }.sorted()
                die(CtxError(cls: "not_found", code: "UNKNOWN_PROTOCOL",
                    message: "no conformances for protocol '\(proto)'", retryable: false,
                    suggestion: near.isEmpty ? "list all: swiftui-ctx conformances" : "did you mean: \(near.joined(separator: ", "))?",
                    exit: .notFound), json: common.json)
            }
            let tops = entry.arr("top_repos").compactMap { p -> [String: Any]? in
                guard let a = p as? [Any], a.count >= 2, let r = a[0] as? String else { return nil }
                return ["repo": r, "count": (a[1] as? Int) ?? (a[1] as? NSNumber)?.intValue ?? 0]
            }
            let exs = entry.arr("examples").compactMap { $0 as? [String: Any] }.prefix(common.limit).map { e -> [String: Any] in
                ["name": e.s("name") ?? "", "repo": e.s("repo") ?? "", "permalink": e.s("permalink") ?? ""]
            }
            let result: [String: Any] = ["protocol": key, "repo_count": entry.i("repo_count") ?? 0,
                "top_repos": Array(tops.prefix(common.limit)), "examples": Array(exs)]
            var next = [NextAction(cmd: "swiftui-ctx lookup \(key)", why: "the protocol's own usage")]
            if let e = exs.first, let pl = e["permalink"] as? String, !pl.isEmpty {
                next.insert(NextAction(cmd: "swiftui-ctx file \(pl) --full", why: "read a real conformer"), at: 0)
            }
            emit(result: result, next: next, json: common.json) {
                var s = "# custom \(key) conformers — \(entry.i("repo_count") ?? 0) repos\ntop: "
                s += tops.prefix(8).map { "\($0["repo"] as? String ?? "")(\($0["count"] as? Int ?? 0))" }.joined(separator: " · ")
                for e in exs { s += "\n  • \(e["name"] as? String ?? "") — \(e["permalink"] as? String ?? "")" }
                return s
            }
        } else {
            let protos = shard.keys.compactMap { k -> [String: Any]? in
                guard let e = shard[k] as? [String: Any] else { return nil }
                return ["protocol": k, "repo_count": e.i("repo_count") ?? 0]
            }.sorted { ($0["repo_count"] as? Int ?? 0) > ($1["repo_count"] as? Int ?? 0) }
            emit(result: ["protocols": protos],
                 next: protos.first.map { [NextAction(cmd: "swiftui-ctx conformances \($0["protocol"] as? String ?? "")", why: "drill into the top protocol")] } ?? [],
                 json: common.json) {
                "# custom conformers by protocol\n" + protos.map { "  \($0["protocol"] as? String ?? "")  \($0["repo_count"] as? Int ?? 0) repos" }.joined(separator: "\n")
            }
        }
    }
}

// ---- rankings — top corpus repos by a dimension (rankings.json) ----
struct Rankings: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Top corpus repos by a ranking dimension (modernity, API breadth, custom components).")
    @OptionGroup var common: Common
    @Argument(help: "Optional: by_total_unique_apis | by_modifier_breadth | by_custom_components | most_modern_stack. Omit to summarize.") var dimension: String?
    static let dims = ["by_total_unique_apis", "by_modifier_breadth", "by_custom_components", "most_modern_stack"]

    func run() {
        let cat = loadCatalog(common)
        let shard = cat.obj("rankings.json")
        func brief(_ r: [String: Any]) -> [String: Any] {
            ["repo": r.s("repo") ?? "", "stars": r.i("stars") ?? 0, "loc": r.i("loc") ?? 0,
             "total_unique_apis": r.i("total_unique_apis") ?? 0, "custom_components": r.i("custom_components") ?? 0,
             "min_macos": r.s("min_macos") ?? NSNull()]
        }
        if let dim = dimension {
            guard let key = Self.dims.first(where: { $0.lowercased() == dim.lowercased() }) else {
                die(CtxError(cls: "usage", code: "UNKNOWN_DIMENSION", message: "no ranking '\(dim)'",
                    retryable: false, suggestion: "one of: \(Self.dims.joined(separator: ", "))", exit: .usage), json: common.json)
            }
            let rows = shard.arr(key).compactMap { $0 as? [String: Any] }.prefix(common.limit).map(brief)
            emit(result: ["dimension": key, "repos": Array(rows)],
                 next: rows.first.map { [NextAction(cmd: "swiftui-ctx repo \($0["repo"] as? String ?? "")", why: "the top repo's full fingerprint")] } ?? [],
                 json: common.json) {
                "# rankings: \(key)\n" + rows.enumerated().map { (i, r) in
                    "  \(i + 1). \(r["repo"] as? String ?? "")  (\(r["stars"] as? Int ?? 0)★, \(r["total_unique_apis"] as? Int ?? 0) APIs, macOS \(r["min_macos"] as? String ?? "?"))"
                }.joined(separator: "\n")
            }
        } else {
            var sizes: [String: Any] = [:]
            for d in Self.dims { sizes[d] = shard.arr(d).count }
            let modern = shard.arr("most_modern_stack").compactMap { $0 as? [String: Any] }.prefix(5).map(brief)
            emit(result: ["dimensions": Self.dims, "sizes": sizes, "most_modern_stack_top5": Array(modern)],
                 next: [NextAction(cmd: "swiftui-ctx rankings most_modern_stack", why: "the modernity leaderboard")],
                 json: common.json) {
                "# rankings — dimensions: \(Self.dims.joined(separator: ", "))\nmost_modern_stack top 5:\n" + modern.map {
                    "  \($0["repo"] as? String ?? "") (\($0["total_unique_apis"] as? Int ?? 0) APIs, macOS \($0["min_macos"] as? String ?? "?"))"
                }.joined(separator: "\n")
            }
        }
    }
}

// ---- insights — corpus-wide signals (insights.json) ----
struct Insights: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Corpus-wide signals: modern-stack adoption %, deprecated usage, co-occurrence, discovered APIs.")
    @OptionGroup var common: Common
    @Argument(help: "Optional section: modern-stack | deprecated | cooccurrence | external | components | categories. Omit to summarize.") var section: String?
    static let map = ["modern-stack": "modern_stack_adoption_pct", "deprecated": "deprecated_api_usage",
        "cooccurrence": "co_occurrence", "external": "discovered_external_api",
        "components": "custom_components_by_kind", "categories": "category_fingerprint"]

    func run() {
        let cat = loadCatalog(common)
        let ins = cat.obj("insights.json")
        if let sec = section?.lowercased(), let key = Self.map[sec] {
            emit(result: ["section": key, "data": ins[key] ?? NSNull()], next: [], json: common.json) {
                "# insights: \(key)\n" + prettySnippet(ins[key])
            }
        } else if section != nil {
            die(CtxError(cls: "usage", code: "UNKNOWN_SECTION", message: "no insights section '\(section ?? "")'",
                retryable: false, suggestion: "one of: \(Self.map.keys.sorted().joined(separator: ", "))", exit: .usage), json: common.json)
        } else {
            let modern = ins.dict("modern_stack_adoption_pct")
            var counts: [String: Int] = [:]
            for k in Self.map.values {
                if let a = ins[k] as? [Any] { counts[k] = a.count } else if let d = ins[k] as? [String: Any] { counts[k] = d.count }
            }
            emit(result: ["modern_stack_adoption_pct": modern, "section_sizes": counts, "sections": Array(Self.map.keys).sorted()],
                 next: [NextAction(cmd: "swiftui-ctx insights deprecated", why: "deprecated APIs still in production")],
                 json: common.json) {
                var s = "# insights — modern-stack adoption (%):\n"
                s += modern.sorted { ($0.value as? Double ?? 0) > ($1.value as? Double ?? 0) }.prefix(10).map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
                s += "\nsections: " + Self.map.keys.sorted().joined(separator: ", ")
                return s
            }
        }
    }
}

// ---- valueBuilders — the Font/Color/Animation/gradient value vocabulary (valueBuilders.json) ----
struct ValueBuilders: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "valueBuilders",
        abstract: "The real Font/Color/Animation/gradient value vocabulary, ranked by production usage.")
    @OptionGroup var common: Common
    @Argument(help: "Optional name filter (e.g. gradient, ease, system, bouncy). Omit to list the top builders.") var filter: String?

    func run() {
        let cat = loadCatalog(common)
        let shard = cat.obj("valueBuilders.json")
        let f = filter?.lowercased()
        var items = shard.compactMap { (k, v) -> [String: Any]? in
            guard let e = v as? [String: Any] else { return nil }
            if let f = f, !k.lowercased().contains(f) { return nil }
            return ["name": k, "total_uses": e.i("total_uses") ?? 0,
                    "repo_count": e.i("repo_count") ?? 0, "low_corpus": e["low_corpus"] as? Bool ?? false]
        }
        items.sort { ($0["total_uses"] as? Int ?? 0) > ($1["total_uses"] as? Int ?? 0) }
        let top = Array(items.prefix(common.limit))
        let result: [String: Any] = ["total": shard.count, "matched": items.count, "builders": top]
        var next: [NextAction] = []
        if let first = top.first, let n = first["name"] as? String {
            next.append(NextAction(cmd: "swiftui-ctx lookup \(n)", why: "per-symbol consensus + real examples"))
        }
        emit(result: result, next: next, json: common.json) {
            var s = "# value builders" + (f != nil ? " matching '\(filter ?? "")'" : "") + " — \(items.count) of \(shard.count), top \(top.count) by use:"
            for b in top {
                s += "\n  \(b["name"] as? String ?? "")  \(b["total_uses"] as? Int ?? 0) uses · \(b["repo_count"] as? Int ?? 0) repos" + ((b["low_corpus"] as? Bool ?? false) ? "  ⚠️ low" : "")
            }
            return s
        }
    }
}

func prettySnippet(_ v: Any?) -> String {
    guard let v = v else { return "(none)" }
    if let d = try? JSONSerialization.data(withJSONObject: v, options: [.prettyPrinted]),
       let s = String(data: d, encoding: .utf8) {
        return String(s.prefix(1600))
    }
    return "\(v)"
}
