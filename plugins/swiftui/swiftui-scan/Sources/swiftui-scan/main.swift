import Foundation
import SwiftSyntax
import SwiftParser

// Per-file result emitted as one JSON line.
struct FileResult: Encodable {
    var path: String
    var imports: [String]
    var loc: Int
    var occurrences: [Occurrence]
    var decls: [Decl]
    var skipped: String?
}

let MAX_BYTES = 2_000_000
let encoder = JSONEncoder()
// compact, stable-ish output; one line per file
encoder.outputFormatting = []

func emit(_ r: FileResult) {
    if let data = try? encoder.encode(r), let s = String(data: data, encoding: .utf8) {
        print(s)
    }
}

// Read newline-delimited file paths from stdin.
while let path = readLine(strippingNewline: true) {
    if path.isEmpty { continue }
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url) else {
        emit(FileResult(path: path, imports: [], loc: 0, occurrences: [], decls: [], skipped: "unreadable"))
        continue
    }
    if data.count > MAX_BYTES {
        emit(FileResult(path: path, imports: [], loc: 0, occurrences: [], decls: [], skipped: "toolarge"))
        continue
    }
    let source = String(decoding: data, as: UTF8.self)
    let lines = source.components(separatedBy: "\n")
    let tree = Parser.parse(source: source)
    let conv = SourceLocationConverter(fileName: path, tree: tree)
    let v = ScanVisitor(conv, lines)
    v.walk(tree)
    emit(FileResult(path: path,
                    imports: v.imports.sorted(),
                    loc: lines.count,
                    occurrences: v.occurrences,
                    decls: v.decls,
                    skipped: nil))
}
