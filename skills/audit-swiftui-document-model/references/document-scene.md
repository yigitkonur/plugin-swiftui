# Reference — Document Scene Architecture (doc-04, doc-05, doc-11)

Depth for the scene layer: the right way to host a document app, the iOS-only launch scene, and manual file
IO that should be the document type's job. Floor values are in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the macOS-arm rule is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`. Verify via Sosumi + `swiftui-ctx`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## doc-04 — `NSDocument` does not belong in a SwiftUI app

A SwiftUI document app uses the **`DocumentGroup`** scene + `FileDocument`/`ReferenceFileDocument`. Reaching
for AppKit's `NSDocument` / `NSDocumentController` inside a SwiftUI lifecycle (`@main struct App: App`)
re-implements (and fights) the machinery `DocumentGroup` already provides — open/save panels, the recents
menu, autosave, versions, the dirty dot. Whether *any* AppKit bridge is justified is owned by
`audit-swiftui-appkit-overuse`; emit doc-04 with `cross_ref: appkit-overuse`.

```swift
// ❌ doc-04 — NSDocument under a SwiftUI @main
final class Document: NSDocument { … }

// ✅ DocumentGroup + a SwiftUI document type
@main struct AcmeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { NoteDocument() }) { file in
            EditorView(document: file.$document)        // mutate via the binding (doc-10)
        }
    }
}
```

The canonical `DocumentGroup` shape from the practice corpus (`swiftui-ctx lookup DocumentGroup`,
`recommended` `ex_91cff38b97`) is `(newDocument:editor:)`, where the editor receives a
`FileDocumentConfiguration` exposing `file.$document` and `file.fileURL`.

---

## doc-05 — `DocumentGroupLaunchScene` has NO macOS arm

`DocumentGroupLaunchScene` (the document-launch experience) is **iOS/iPadOS-only** — there is no macOS
implementation. On the Mac, `DocumentGroup` already presents the standard open panel / template chooser, so
there is nothing to replace. If it appears in a macOS target it is a hard-fail (it won't be available and
indicates copied iOS code). Remove it on the macOS path; if the project is multiplatform, gate it to the iOS
arm only (`#if os(iOS)` or `#available` on the iOS arm — see the macOS-arm-gating reference). Emit doc-05
with `cross_ref: scenes-windows`.

This is the document-domain instance of the toolkit's "no-macOS-arm scene" trap: a scene type that simply
has no Mac equivalent, distinct from a *wrong-arm availability gate*.

---

## doc-11 — manual file IO inside a document app

In a `DocumentGroup` app, opening/saving is the document type's responsibility (`init(configuration:)` /
`fileWrapper(...)`). Hand-rolled `FileManager.default` reads/writes, `Data(contentsOf:)`, or an
`NSSavePanel` / `NSOpenPanel` invoked to load/save the *primary* document duplicate that machinery and
bypass autosave, versions, and security-scoped access. This is advisory (doc-11) — some manual IO is
legitimate (exporting a derived artifact, importing an *auxiliary* asset). When the IO is for sandboxed user
files (consent, security-scoped bookmarks), the correctness of that consent is owned by
`audit-swiftui-sandbox-files` — emit doc-11 with `cross_ref: sandbox-files`. READ to confirm it is the
primary document path before flagging.

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/swiftui/documentgroup`,
  `/documentation/swiftui/documentgrouplaunchscene`,
  `https://developer.apple.com/documentation/appkit/nsdocument`.
- Apple — "Building a document-based app with SwiftUI"
  (`/documentation/swiftui/building-a-document-based-app-with-swiftui`), via Sosumi.
- Practice corpus — `swiftui-ctx lookup DocumentGroup --json` (consensus `(newDocument:)`; `recommended`
  `ex_91cff38b97` → `https://github.com/RobertoMachorro/Moped/blob/5b109e33c83d38456a787115ec49fc28ced2bebe/Moped/MopedApp.swift#L28`).
