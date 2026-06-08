# Consent & Security-Scoped Bookmarks (sf-01 · sf-02 · sf-03)

The App Sandbox is **invisible in Swift source** — there is no API that says "I am sandboxed." It is a
build-time capability driven by a `.entitlements` plist, so a model reasoning purely about Swift sees
nothing to gate against and writes `FileManager` / `Data(contentsOf:)` against arbitrary paths exactly as
it would for a CLI tool. On macOS that code compiles, the path exists, the *user* can read it — and the
call still fails at runtime with a permission error. **The default path here is SANDBOXED** (Mac App
Store requires it; a new Xcode macOS target enables it). The governing rule: **holding a URL is NOT the
same as being allowed to open it.**

> Scope note: the `loadTransferable` Swift-6 Sendable race that lives next to a picker is **not** here —
> `audit-swiftui-concurrency-safety` owns the isolation fix; this skill owns the file-consent angle and
> `cross_ref`s it (see `transferable-and-clipboard.md`, sf-07). *Whether* an `NSOpenPanel` bridge should
> exist is `audit-swiftui-appkit-overuse`; bookmark correctness *once* a panel/importer is chosen is here.

---

## sf-01 — reading/writing an arbitrary path with no user consent (most common)

```swift
// ❌ WRONG — a literal / typed path outside the container; compiles, path exists, fails at runtime
let home = FileManager.default.homeDirectoryForCurrentUser   // ~/ — still outside the sandbox container
let text = try String(contentsOf: home.appendingPathComponent("Documents/notes.txt"))
```

A sandboxed app cannot read a path it wasn't explicitly granted. Get the URL through a system panel — the
panel runs in a separate process and hands back a URL with a temporary sandbox extension — and declare the
matching entitlement (sf-04), or even the panel-derived read silently fails. The one exception that is
always readable is **`Bundle.main`** (the app's own resources).

**✅ Correct (consensus + permalink, not a hand-written snippet).** `swiftui-ctx lookup fileImporter`
reports the canonical shape and the highest-authority current example. The consensus is
`(isPresented, allowedContentTypes, allowsMultipleSelection)` (65% of real uses); the `recommended`
example is `sindresorhus/Gifski` (`min_macos: 26`, author authority ~1.0M) — fetch its real enclosing view
with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file ex_b884986158 --smart`:

```swift
// ✅ CORRECT — the URL comes from a user-driven panel, which mints a sandbox extension for that file
.fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
    guard case let .success(url) = result else { return }
    // `url` is reachable ONLY because the user chose it through the panel
    try? persist(url)
}
```

The canonical macOS example (Gifski `MainScreen.swift#L26`):
`.fileImporter(isPresented: $appState.isFileImporterPresented, allowedContentTypes: Device.supportedVideoTypes)`.
AppKit's `NSOpenPanel` / `NSSavePanel` are equivalent; SwiftUI's `fileImporter` / `fileExporter` wrap them.

---

## sf-02 — re-opening a user-chosen file next launch with no security-scoped bookmark

```swift
// ❌ WRONG — persist the path/URL; re-open next launch → unreachable, the grant is gone
UserDefaults.standard.set(url.path, forKey: "lastFile")          // path string
UserDefaults.standard.set(try? url.bookmarkData(), forKey: "x")  // plain bookmark, NOT security-scoped
```

The sandbox grant for a user-selected file **does not survive relaunch**. A plain `bookmarkData()` (no
`.withSecurityScope`) round-trips the *path* but not the *permission*.

```swift
// ✅ CORRECT — mint a SECURITY-SCOPED bookmark, persist the Data, resolve with .withSecurityScope
func persist(_ url: URL) throws {
    let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
    UserDefaults.standard.set(bookmark, forKey: "lastFile")
}
```

If `bookmarkDataIsStale == true` on resolve, **re-create the bookmark while you still have access**.
Persisting an *app-scoped* (not document-scoped) bookmark also needs the
`com.apple.security.files.bookmarks.app-scope` entitlement (sf-04).

---

## sf-03 — `start` access with no balancing `stop` (ref-count leak)

```swift
// ❌ WRONG — start without a balancing stop → the extension leaks; LATER file access is denied
_ = url.startAccessingSecurityScopedResource()      // ignored Bool, no defer/stop
return try String(contentsOf: url)                  // never calls stopAccessing… → ref-count leak
```

```swift
// ✅ CORRECT — resolve, guard the Bool grant, balance start with stop via defer
func reopen() throws -> String {
    let data = UserDefaults.standard.data(forKey: "lastFile")!
    var stale = false
    let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope,
                      relativeTo: nil, bookmarkDataIsStale: &stale)
    guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
    defer { url.stopAccessingSecurityScopedResource() }   // ALWAYS balance start with stop
    return try String(contentsOf: url)
}
```

`startAccessingSecurityScopedResource()` (macOS 10.10+) returns a `Bool` grant and is **ref-counted** —
every `start` needs exactly one balancing `stop` (use `defer`), or you leak the extension and a later
access is denied. Ignoring the returned `Bool` hides the denial.

---

## The consent test (the audit's core judgment)

Trace each file URL back to its origin:

| Origin in source | Verdict |
|---|---|
| a system panel (`fileImporter`/`fileExporter`/`NSOpenPanel`/`NSSavePanel`) | **granted** (temporary) |
| a resolved `.withSecurityScope` bookmark inside `start`/`stop` | **granted** (persisted) |
| a `Bundle.main` URL | **granted** (own container) |
| a string literal / `URL(fileURLWithPath:)` / a `.path` from `UserDefaults` | **ungranted → sf-01/02** |
| a plain `bookmarkData()` (no `.withSecurityScope`) | **ungranted → sf-02** |

**Optional `_consent-map.md` artifact:** classify every file URL in the project by origin and mark its
consent state; score consent coverage = granted URLs / total file URLs. Two runs over the same code
produce identical maps.

> macOS-specific: the sandbox lets a Mac app *reach out* (document/editor apps legitimately open files all
> over the disk) — but only via consent + bookmarks; iOS never does, so this concept is absent from
> iOS-shaped training data.

---

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox | primary-doc | high (page) / medium (body) | Canonical "user-driven access via open/save panel + security-scoped bookmarks"; sandbox grants the container plus user-selected files. Body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/foundation/url/bookmarkcreationoptions/withsecurityscope | primary-doc | high (symbol) / medium (body) | `.withSecurityScope` bookmark option — the flag that makes a bookmark re-grantable across launches. Symbol confirmed; body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource() | primary-doc | high (symbol) | Returns a `Bool` grant and is **ref-counted** — each call must be balanced by one `stopAccessingSecurityScopedResource()`. macOS 10.10+. Accessed 2026-06-06. |
| https://www.hackingwithswift.com/example-code/system/how-to-use-security-scoped-bookmarks-to-access-the-file-system | practitioner | high | The canonical `bookmarkData(options: .withSecurityScope)` ↔ `startAccessingSecurityScopedResource()` round-trip, incl. the stale-bookmark re-create. Accessed 2026-06-06. |
| swiftui-ctx `lookup fileImporter` + `file ex_b884986158 --smart` (corpus of 1,857 macOS apps) | practice | high | consensus `(isPresented, allowedContentTypes, allowsMultipleSelection)` 65%; `recommended` = `sindresorhus/Gifski` `MainScreen.swift#L26` (min_macos 26); `introduced_macos: 11.0`; `doc:` https://sosumi.ai/documentation/swiftui/view/fileimporter. Run 2026-06-07. |

Floors are cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
(`fileExporter`/`fileImporter` macOS 11.0+, `startAccessingSecurityScopedResource()` macOS 10.10+) and
fetched via Sosumi (access 2026-06-07). The Apple doc bodies render via JavaScript — symbol names, page
identities, and availability are confirmed; verbatim body prose was not captured. Where exact prose
matters, **verify against Xcode 26 SDK**.
