import Foundation
import SwiftSyntax
import SwiftParser

struct PermalinkParts { let owner, repo, sha, path: String; let line: Int }

func parsePermalink(_ url: String) -> PermalinkParts? {
    // https://github.com/<owner>/<repo>/blob/<sha>/<path>#L<line>
    guard let hashIdx = url.range(of: "#L") else { return nil }
    let line = Int(url[hashIdx.upperBound...]) ?? 1
    let base = String(url[url.startIndex..<hashIdx.lowerBound])
    guard let r = base.range(of: "github.com/") else { return nil }
    let rest = String(base[r.upperBound...])              // owner/repo/blob/sha/path...
    let parts = rest.split(separator: "/", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 5, parts[2] == "blob" else { return nil }
    return PermalinkParts(owner: parts[0], repo: parts[1], sha: parts[3], path: parts[4], line: line)
}

func rawURL(_ p: PermalinkParts) -> URL {
    URL(string: "https://raw.githubusercontent.com/\(p.owner)/\(p.repo)/\(p.sha)/\(p.path)")!
}

func cacheURL(_ p: PermalinkParts) -> URL {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cache/swiftui-ctx/\(p.owner)__\(p.repo)__\(p.sha)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent((p.path as NSString).lastPathComponent)
}

func fetchFile(_ p: PermalinkParts) throws -> String {
    let cache = cacheURL(p)
    if let cached = try? String(contentsOf: cache, encoding: .utf8) { return cached }
    do {
        let data = try Data(contentsOf: rawURL(p))           // sha is immutable → safe to cache
        let s = String(decoding: data, as: UTF8.self)
        try? s.write(to: cache, atomically: true, encoding: .utf8)
        return s
    } catch {
        throw CtxError(cls: "transient", code: "FETCH_FAILED",
            message: "could not fetch \(rawURL(p).absoluteString): \(error.localizedDescription)",
            retryable: true, suggestion: "retry, or use --offline to show the cached snippet line", exit: .network)
    }
}

// Find the line range to show, by mode, using a real Swift parse.
enum SpanMode { case smart, decl, chain, full }
let SMART_CAP = 80      // smart mode won't dump a span larger than this

func extractSpan(_ source: String, line: Int, mode: SpanMode) -> (Int, Int) {
    let lineCount = source.split(separator: "\n", omittingEmptySubsequences: false).count
    if mode == .full { return (1, lineCount) }
    let tree = Parser.parse(source: source)
    let conv = SourceLocationConverter(fileName: "f.swift", tree: tree)
    let finder = SpanFinder(line: line, conv: conv)
    finder.walk(tree)
    switch mode {
    case .decl:  if let d = finder.decl { return d }
    case .chain: if let c = finder.chain { return c }
    case .smart:
        // 1) the enclosing decl (var body / func) if it fits → a compilable, self-contained view
        if let d = finder.decl, d.1 - d.0 <= SMART_CAP { return d }
        // 2) else the tightest statement/chain that fits (each is guaranteed to contain the anchor)
        let fit = [finder.stmt, finder.chain].compactMap { $0 }
            .filter { $0.1 - $0.0 <= SMART_CAP }.sorted { ($0.1-$0.0) < ($1.1-$1.0) }
        if let best = fit.first { return best }
        // 3) everything is huge → an ANCHORED window (always contains the target line)
        return (max(1, line - 15), min(lineCount, line + 45))
    case .full: break
    }
    return (max(1, line - 8), min(lineCount, line + 8))      // fallback window (always contains the anchor)
}

final class SpanFinder: SyntaxVisitor {
    let line: Int; let conv: SourceLocationConverter
    var decl: (Int, Int)?    // smallest enclosing var/func decl
    var stmt: (Int, Int)?    // smallest enclosing statement
    var chain: (Int, Int)?   // widest enclosing call (the modifier chain)
    init(line: Int, conv: SourceLocationConverter) {
        self.line = line; self.conv = conv
        super.init(viewMode: .sourceAccurate)
    }
    private func span(_ n: some SyntaxProtocol) -> (Int, Int) {
        (n.startLocation(converter: conv).line, n.endLocation(converter: conv).line)
    }
    private func smaller(_ cur: (Int,Int)?, _ n: some SyntaxProtocol) -> (Int,Int)? {
        let (s,e) = span(n); guard s <= line, line <= e else { return cur }
        if cur == nil || (e-s) < (cur!.1-cur!.0) { return (s,e) }; return cur
    }
    private func wider(_ cur: (Int,Int)?, _ n: some SyntaxProtocol) -> (Int,Int)? {
        let (s,e) = span(n); guard s <= line, line <= e else { return cur }
        if cur == nil || (e-s) > (cur!.1-cur!.0) { return (s,e) }; return cur
    }
    override func visit(_ n: VariableDeclSyntax) -> SyntaxVisitorContinueKind { decl = smaller(decl, n); return .visitChildren }
    override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { decl = smaller(decl, n); return .visitChildren }
    override func visit(_ n: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind { stmt = smaller(stmt, n); return .visitChildren }
    override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind { chain = wider(chain, n); return .visitChildren }
}

func sliceLines(_ source: String, _ range: (Int, Int)) -> String {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    let a = max(1, range.0), b = min(lines.count, range.1)
    guard a <= b else { return "" }
    return lines[(a-1)..<b].enumerated()
        .map { "\(a + $0.offset)\t\($0.element)" }.joined(separator: "\n")
}
