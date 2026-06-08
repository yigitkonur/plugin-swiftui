# Reference — Content Types & UTTypes (doc-06, doc-07)

Depth for the content-type contract: what a document declares it can read/write, and how a custom file type
must be registered. Floor values are in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; verify
any uncertain symbol via Sosumi and `swiftui-ctx lookup UTType --json`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## The contract

A document type declares two static arrays of `UTType`:

```swift
static var readableContentTypes: [UTType] { [.plainText] }      // can open
static var writableContentTypes: [UTType] { [.plainText] }      // can save  (defaults to readable)
```

- A `DocumentGroup(newDocument:)`'s `UTType` must match the document's `writableContentTypes`, or the new
  document is created with a type the document cannot save.
- A built-in type (`.plainText`, `.pdf`, `.json`, `.png`, `.rtf`) needs no declaration. A **custom** type
  does.

---

## doc-06 — a custom UTType must be declared in Info.plist

`UTType(exportedAs: "com.acme.note")` / `UTType(importedAs:)` returns a type that is only meaningful if the
app **declares** it in `Info.plist`:

- **Exported** (your app owns the format): `UTExportedTypeDeclarations` — with
  `UTTypeIdentifier`, `UTTypeConformsTo` (e.g. `public.data` / `public.content`),
  `UTTypeTagSpecification` (the file extension), and a description.
- **Imported** (a format another app owns, that yours reads): `UTImportedTypeDeclarations`.
- The document scene must also appear under `CFBundleDocumentTypes` so Finder routes the file to the app.

Without the declaration the UTType is unrecognized: the open panel won't show the file, double-click won't
launch the app, and `readableContentTypes` silently fails to match. The grep tell `UTType(exportedAs:` /
`importedAs:` is a **locator** — READ `Info.plist` (or the `*.entitlements`/`project.pbxproj`
`INFOPLIST_KEY_*`) to confirm the matching declaration exists. If it's missing, that is the doc-06 finding.

```swift
// ❌ doc-06 — used but never declared
static var readableContentTypes: [UTType] { [UTType(exportedAs: "com.acme.note")] }
// (no UTExportedTypeDeclarations entry in Info.plist)

// ✅ declare it
extension UTType { static let acmeNote = UTType(exportedAs: "com.acme.note") }
// + Info.plist UTExportedTypeDeclarations { UTTypeIdentifier=com.acme.note,
//   UTTypeConformsTo=[public.data], UTTypeTagSpecification={ public.filename-extension=[note] } }
// + CFBundleDocumentTypes referencing com.acme.note
```

---

## doc-07 — an editable document with no writableContentTypes is read-only by accident

`writableContentTypes` defaults to `readableContentTypes` **only** if you don't override `readable`. When a
document overrides `readableContentTypes` (to add types it can open but not save) and *forgets*
`writableContentTypes`, or sets `writableContentTypes` to an empty array, the document silently becomes
read-only — Save does nothing and the format round-trips wrong. The grep tell on `readableContentTypes` is a
locator; READ the type to confirm `writableContentTypes` is present and covers what the app saves. A
genuinely viewer-only app (`DocumentGroup(viewing:)`) is correct and should NOT be flagged.

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/swiftui/filedocument/readablecontenttypes`,
  `/documentation/swiftui/filedocument/writablecontenttypes`,
  `https://developer.apple.com/documentation/uniformtypeidentifiers/uttype`,
  `https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app`.
- Apple — "Building a document-based app with SwiftUI" (the content-type + Info.plist setup), via Sosumi.
- Practice corpus — `swiftui-ctx lookup UTType --json` / `swiftui-ctx examples UTType` for real call sites.
