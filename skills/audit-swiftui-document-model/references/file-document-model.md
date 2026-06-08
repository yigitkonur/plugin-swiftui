# Reference — FileDocument vs ReferenceFileDocument (the model layer)

Depth for doc-02, doc-03, doc-08, doc-09, doc-10, doc-12 — the document *type* and how its data reaches
disk safely. Floor values are in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; verify any
uncertain symbol via Sosumi and `swiftui-ctx lookup <api> --json`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## The value/reference decision (doc-02, doc-03)

| Choose… | When the model is… | Conformance | Write path |
|---|---|---|---|
| `FileDocument` (**struct**) | small, fully snapshot-serializable, copied cheaply | `struct Doc: FileDocument` | SwiftUI copies the **value**, calls `fileWrapper(configuration:)` off-main |
| `ReferenceFileDocument` (**class**) | large, a graph, observed, mutated incrementally | `final class Doc: ReferenceFileDocument, ObservableObject` | SwiftUI calls `snapshot(contentType:)` on-main → serializes the **snapshot** off-main |

**doc-02 — a class conforming to `FileDocument`.** `FileDocument` is a value protocol; a `class` conforming
to it breaks value semantics (SwiftUI expects to copy it before writing). Either make it a `struct` or, if
reference semantics are genuinely needed, switch to `ReferenceFileDocument`.

```swift
// ❌ doc-02
final class NoteDocument: FileDocument { … }          // value protocol on a reference type

// ✅ value model
struct NoteDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,           // doc-09: guard, no `!`
              let s = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        text = s
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
```

**doc-03 — `ReferenceFileDocument` with no `snapshot(contentType:)`.** The protocol requires
`func snapshot(contentType:) throws -> Snapshot` (capture a consistent value on the main actor) **and**
`fileWrapper(snapshot:configuration:)` (serialize that snapshot off-main). Omitting `snapshot` fails to
compile, or — if conformance is split into an extension — leaves the write incomplete. The ast-grep rule
`doc-03-reference-missing-snapshot.yml` flags the declaration; READ to confirm no extension supplies it.

```swift
// ✅ reference model
final class CanvasDocument: ReferenceFileDocument, ObservableObject {
    typealias Snapshot = [Shape]
    @Published var shapes: [Shape] = []
    static var readableContentTypes: [UTType] { [.canvasDocument] }
    static var writableContentTypes: [UTType] { [.canvasDocument] }       // doc-07
    init(configuration: ReadConfiguration) throws { … }
    func snapshot(contentType: UTType) throws -> [Shape] { shapes }       // doc-03: required
    func fileWrapper(snapshot: [Shape], configuration: WriteConfiguration) throws -> FileWrapper { … }
}
```

---

## doc-08 — never serialize on the main actor

Apple's guidance is explicit: **"Don't perform serialization on MainActor."** A document type annotated
`@MainActor` (the ast-grep rule `doc-08-mainactor-document.yml`) forces `init(configuration:)` and
`fileWrapper(...)` onto the main thread, blocking the UI on every open/save of a large file. The document's
serialization should be **`Sendable`** and run off-main; for a reference document, `snapshot(contentType:)`
runs on-main (cheap value capture) and `fileWrapper(snapshot:…)` runs off-main. Correctness of the actor
isolation is owned by `audit-swiftui-concurrency-safety` — emit doc-08 with `cross_ref:
concurrency-safety`.

---

## doc-09 — FileWrapper handling (data loss)

`FileWrapper.regularFileContents` is **optional** — it is `nil` for a directory wrapper or an empty file.
Force-unwrapping (`regularFileContents!`) crashes; reading it without checking the wrapper kind corrupts a
package document. Guard it, and for a directory document inspect `fileWrappers` (the child map). For an
incremental save, reuse unchanged child wrappers rather than rewriting the whole package.

---

## doc-10 — mutate through the binding (dirty-state / autosave)

SwiftUI marks the scene dirty and triggers autosave only when the document changes **through its binding**.
`FileDocumentConfiguration` exposes `$document` (a `Binding`); for a reference document the `@ObservedObject`
/ `@Observable` instance is itself observed. Mutating a *copy* — or `configuration.document` (the non-binding
`let`) — directly leaves the scene clean: edits never autosave and are silently lost on close. This is a
semantic check (no clean grep tell; `configuration.document` is only a locator) — READ the edit path and
confirm every mutation flows through `$document` / the observed reference.

---

## doc-12 — undo wiring (reference documents)

A `ReferenceFileDocument` app should register edits with the document's `UndoManager` so ⌘Z works and the
dirty/clean state tracks correctly: read `@Environment(\.undoManager)` in the editing view and wrap each
mutation in `undoManager?.registerUndo(withTarget:…)`. A reference document with no `UndoManager` usage is
advisory (doc-12) — confirm undo is actually required for the app before flagging.

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/swiftui/filedocument`,
  `/documentation/swiftui/referencefiledocument`,
  `/documentation/swiftui/referencefiledocument/snapshot(contenttype:)`,
  `/documentation/swiftui/filedocumentconfiguration`,
  `https://developer.apple.com/documentation/foundation/filewrapper`.
- Apple — "Building a document-based app with SwiftUI"
  (`/documentation/swiftui/building-a-document-based-app-with-swiftui`) — the "Don't perform serialization
  on MainActor" guidance — via Sosumi.
- Practice corpus — `swiftui-ctx lookup DocumentGroup --json` (`co_occurs_with` focused-value APIs);
  fetch a real macOS document type with `swiftui-ctx file <recommended.id> --smart`.
