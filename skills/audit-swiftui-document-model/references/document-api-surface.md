# Reference — The Real Document API Surface (macOS)

The allow-list of real SwiftUI document-architecture symbols, plus the one phantom this skill detects
(`@FocusedDocument`). This is the spine the other references cite. Per-platform floor *values* are not
restated here — they live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (the single source
of availability truth). This file carries the **signatures, the existence allow-list, and the
`@FocusedDocument` ❌→✅ rewrite**.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## Why AI gets this wrong

The document API (`DocumentGroup`/`FileDocument`/`ReferenceFileDocument`) shipped at WWDC20 (macOS 11.0+)
but is thinly represented in training data — most SwiftUI sample code is single-window, not document-based.
Two failure shapes:

1. **The value/reference confusion.** `FileDocument` is a **value** (struct) protocol; `ReferenceFileDocument`
   is a **reference** (class) protocol with extra requirements (`snapshot(contentType:)`). The model mixes
   them — a `class … : FileDocument` (doc-02) or a `ReferenceFileDocument` with no `snapshot` (doc-03).
2. **Invention by analogy.** SwiftUI has `@FocusedValue`, `@FocusedBinding`, `@FocusedObject` — so the model
   invents `@FocusedDocument` to read the focused document. **It does not exist.**

---

## The real symbol allow-list (these exist on macOS)

Confirm any floor against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; verify any uncertain
symbol via Sosumi (`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`) and via `swiftui-ctx
lookup <api> --json` (the practice corpus).

| Symbol | Role | Apple doc path (`/documentation/swiftui/…`) |
|---|---|---|
| `DocumentGroup` | the document scene; `(newDocument:)`/`(viewing:)`/`(editing:migrationPlan:)` | `documentgroup` |
| `FileDocument` | **value** document protocol (struct) | `filedocument` |
| `ReferenceFileDocument` | **reference** document protocol (class, `Sendable`) — requires `snapshot(contentType:)` | `referencefiledocument` |
| `FileDocumentConfiguration` | gives the `$document` **binding** + `fileURL` + `isEditable` | `filedocumentconfiguration` |
| `ReferenceFileDocumentConfiguration` | the reference-document equivalent | `referencefiledocumentconfiguration` |
| `static readableContentTypes: [UTType]` | the types the document can open | `filedocument/readablecontenttypes` |
| `static writableContentTypes: [UTType]` | the types the document can save | `filedocument/writablecontenttypes` |
| `init(configuration:)` | the read path | `filedocument/init(configuration:)` |
| `fileWrapper(configuration:)` | the write path (FileDocument) | `filedocument/filewrapper(configuration:)` |
| `fileWrapper(snapshot:configuration:)` | the write path (ReferenceFileDocument) | `referencefiledocument/filewrapper(snapshot:configuration:)` |
| `func snapshot(contentType:)` | reference-doc: capture a value to serialize off-main | `referencefiledocument/snapshot(contenttype:)` |
| `FileWrapper` (Foundation) | the on-disk representation (regular file or directory) | (Foundation `filewrapper`) |
| `UTType(exportedAs:)` / `(importedAs:)` | a custom content type backed by an `Info.plist` declaration | (UniformTypeIdentifiers) |

`DocumentGroup`'s consensus call shape from the practice corpus (`swiftui-ctx lookup DocumentGroup`) is
`(newDocument:)` (77%), with `(newDocument:editor:)` as the `recommended` permalinked example
(`RobertoMachorro/Moped` `MopedApp.swift#L28`). Its frequent `co_occurs_with` neighbours include
`focusedSceneValue` / `focusedValue` / `commandsRemoved` / `inspector` — the real way to wire a
focused-document command (see the `@FocusedDocument` rewrite below).

**`DocumentGroupLaunchScene` is iOS/iPadOS-only — there is NO macOS arm** (doc-05; see `document-scene.md`).

---

## The phantom: `@FocusedDocument` (detect + replace)

`@FocusedDocument` is **not a real Apple symbol** (the canonical entry is in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`). A `swiftui-ctx lookup
FocusedDocument` returns `ok:false`, `error.class: not_found` (with a did-you-mean `suggestion`) — no
shipping Mac app uses it. To expose the active document to menu commands, define a custom `FocusedValues`
key:

```swift
// ❌ phantom
@FocusedDocument var document: MyDocument?

// ✅ custom FocusedValues @Entry key (@Entry back-deploys to macOS 10.15+ — needs Xcode 15+/Swift 5.9+ to expand; FocusedValueKey is macOS 11+ — confirm both against floors-master.md)
extension FocusedValues {
    @Entry var focusedDocument: MyDocument?
}
// in the document view:
.focusedSceneValue(\.focusedDocument, document)
// in a Commands body:
@FocusedValue(\.focusedDocument) private var document: MyDocument?
```

Confirm the `@Entry` floor against `floors-master.md` before annotating; pre-`@Entry` projects write the
explicit `FocusedValueKey` conformance instead.

---

## Detection tells (for DETECT; the deterministic version is `lint/grep-tells.tsv`)

- Phantom (doc-01): `@FocusedDocument`
- Value/reference confusion (doc-02): `class\s+\w+[^{]*:\s*[^{]*\bFileDocument\b`

---

## Sources

- Apple — SwiftUI document-app symbol pages, fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/swiftui/documentgroup`,
  `/documentation/swiftui/filedocument`, `/documentation/swiftui/referencefiledocument`,
  `/documentation/swiftui/filedocumentconfiguration`, `/documentation/swiftui/focusedvalues`.
- Apple — "Building a document-based app with SwiftUI"
  (`/documentation/swiftui/building-a-document-based-app-with-swiftui`), via Sosumi.
- WWDC20 — "Build document-based apps in SwiftUI" (`/videos/play/wwdc2020/10039`), via Sosumi.
- Practice corpus — `swiftui-ctx lookup DocumentGroup` (consensus `(newDocument:)`; `recommended`
  `ex_91cff38b97` → `https://github.com/RobertoMachorro/Moped/blob/5b109e33c83d38456a787115ec49fc28ced2bebe/Moped/MopedApp.swift#L28`).
