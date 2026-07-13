# App Sandbox, Entitlements & File Access (macOS)

The App Sandbox is **invisible in Swift source** — there is no API that says "I am sandboxed." It is a build-time capability driven by a `.entitlements` property list, so a model reasoning purely about Swift sees nothing to gate against and writes `FileManager` / `Data(contentsOf:)` against arbitrary paths exactly as it would for a CLI tool. On macOS that code compiles, the path exists, the *user* can read it — and the call still fails at runtime with a permission error. A sandboxed app reaches only its own container plus files the **user** hands it through a system open/save panel.

> **Scope: macOS only.** App Sandbox + entitlements + security-scoped bookmarks are a Mac **distribution** reality with no iOS-simple analog. iOS apps are always sandboxed but never reach outside their container the way a Mac document/editor app must; the entire "you hold a URL but still may not open it" rule has no iOS equivalent. `UIPasteboard` **does not exist on macOS** — the clipboard is `NSPasteboard`.
>
> **Why AI gets this wrong:** training data is iOS-shaped, where the app never legitimately touches a path the user didn't already hand it, so the *concept* of security-scoped bookmarks is absent from the model's priors. Layered on: Hardened Runtime / notarization are *distribution* concerns that never appear in tutorial code, and Swift 6 strict concurrency turned previously-compiling drag-drop / `loadTransferable` code into hard errors because the transferred value crosses actor boundaries.
>
> **The default guidance here is the SANDBOXED path** (Mac App Store requires it; a new Xcode macOS target enables it). The counter-intuitive rule that governs everything below: **holding a URL is NOT the same as being allowed to open it.**

---

## Sandbox ON vs OFF — the one architectural fork

Sandbox is the default and the App Store gate, but it is a wall, not a suggestion. An app that must read a private framework, install a session-wide `CGEventTap`, spawn ad-hoc subprocesses, or call `AXIsProcessTrustedWithOptions` (global accessibility) **cannot be sandboxed at all** — none of those are permitted under App Sandbox. Such an app ships **Developer ID + notarization only** (no Mac App Store) and omits the `com.apple.security.app-sandbox` key entirely.

| | Sandbox ON (default, this doc) | Sandbox OFF (e.g. a notch/overlay/automation app) |
|---|---|---|
| Mac App Store | required & eligible | impossible |
| Arbitrary file reach | user-consent + bookmarks only | free (TCC still gates some dirs) |
| Private frameworks / `CGEventTap` / subprocesses | forbidden | allowed (notarization scans for malware, not API policy) |
| Distribution | App Store **or** Developer ID | Developer ID + notarization only |

Both still want **Hardened Runtime ON** for notarization. Pick sandbox-ON unless a capability above forces OFF; do not disable the sandbox to "make file code work" — that is mistake 1, not a fix.

---

## The 6 mistakes (❌ WRONG / ✅ CORRECT)

### 1. Reading/writing arbitrary paths in a sandboxed app — no user consent (most common)

```swift
// ❌ WRONG — a literal/typed path; compiles, path exists, still fails at runtime
let text = try String(contentsOf: URL(fileURLWithPath: "/path/to/notes.txt"))
```

```swift
// ✅ CORRECT — the URL comes from a user-driven picker, which mints a sandbox extension for that file
.fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
    guard case let .success(url) = result else { return }
    // `url` is reachable ONLY because the user chose it through the panel
    persist(url)
}
```

A sandboxed app cannot read paths it wasn't explicitly granted. Get the URL through `fileImporter` / `fileExporter` (SwiftUI) or `NSOpenPanel` / `NSSavePanel` (AppKit) — the panel runs in a separate process and hands back a URL with a temporary grant. And declare the matching entitlement (mistake 3), or even the panel-derived read silently fails.

### 2. Re-opening a user-chosen file next launch without a security-scoped bookmark

```swift
// ❌ WRONG — persist the path/URL, re-open next launch → unreachable, the grant is gone
UserDefaults.standard.set(url.path, forKey: "lastFile")          // path string
UserDefaults.standard.set(try? url.bookmarkData(), forKey: "x")  // plain bookmark, NOT security-scoped

// ❌ ALSO WRONG — start without a balancing stop → the grant leaks; LATER file access is denied
_ = url.startAccessingSecurityScopedResource()                   // ignored Bool; no defer/stop
return try String(contentsOf: url)                               // never calls stopAccessing… → ref-count leak
```

```swift
// ✅ CORRECT — mint a SECURITY-SCOPED bookmark, persist the Data, wrap re-access in start/stopAccessing
func persist(_ url: URL) throws {
    let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
    UserDefaults.standard.set(bookmark, forKey: "lastFile")
}
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

The sandbox grant for a user-selected file **does not survive relaunch**. This is the single most counter-intuitive rule: *holding the URL is not the same as being allowed to open it.* A plain `bookmarkData()` (no `.withSecurityScope`) round-trips the path but not the *permission*. If `stale == true`, re-create the bookmark while you still have access. Security-scoped access is **ref-counted** — every `start` needs a balancing `stop` (use `defer`), or you leak the extension.

### 3. Forgetting the entitlements — sandbox on, file/network off

```xml
<!-- ❌ WRONG — App Sandbox enabled but no capability keys: panel reads AND URLSession silently fail -->
<dict>
    <key>com.apple.security.app-sandbox</key> <true/>
    <!-- nothing else: even fileImporter's URL can't be read; URLSession is blocked -->
</dict>
```

```xml
<!-- ✅ CORRECT — declare exactly the capabilities you use (MyApp.entitlements) -->
<dict>
    <key>com.apple.security.app-sandbox</key>                      <true/>   <!-- required for App Store -->
    <key>com.apple.security.files.user-selected.read-write</key>  <true/>   <!-- or …read-only -->
    <key>com.apple.security.network.client</key>                  <true/>   <!-- ONLY if you make requests -->
    <!-- add only if you persist app-scoped (not document-scoped) bookmarks: -->
    <!-- <key>com.apple.security.files.bookmarks.app-scope</key>  <true/> -->
</dict>
```

The App Sandbox is opt-in **per entitlement**. Enabling the sandbox without `files.user-selected.read-write` (or `.read-only`) means even a user-picked URL is unreadable; without `network.client` your `URLSession` calls fail. Declare every key you use and **no more** — each entitlement widens the attack surface and App Review questions unused ones. Use `.read-only` if you never write the user's files.

### 4. Drag-drop / `loadTransferable` that compiled pre-Swift-6 now errors

```swift
// ❌ WRONG — main-actor value crosses into the nonisolated .task / transfer closure → data race
struct AddView: View {
    @State private var item: PhotosPickerItem?
    var body: some View {
        SomeView().task {
            let data = try? await item?.loadTransferable(type: Data.self)  // ❌ Swift 6 error
        }
    }
}
// error: "Sending main actor-isolated value of type 'PhotosPickerItem' with later accesses
//         to nonisolated context risks causing data races"   (MainActor.run wrapping alone won't fix it)
```

```swift
// ✅ CORRECT — own the item + the async work in an @Observable model; relocate state off the view boundary
@Observable @MainActor final class PhotoLoader {
    var item: PhotosPickerItem?
    func load() async -> Data? { try? await item?.loadTransferable(type: Data.self) }
}
struct AddView: View {
    @State private var loader = PhotoLoader()
    var body: some View { SomeView().task { _ = await loader.load() } }
}
```

Under the Swift 6 language mode strict concurrency is on by default. A main-actor-isolated value (a `PhotosPickerItem` born in a `@MainActor` view) read inside the *nonisolated* `.task` / transfer closure is a hard error. The community fix is to **move the state and the transfer work into a model** (created as `@State`), not to sprinkle `MainActor.run`. (A fresh Xcode 26 target may ship *Default Actor Isolation = Main Actor* (`-default-isolation MainActor`), which can pre-isolate and mask this — never assume that mode is on; it is an opt-in build setting, not the language default — verify against your Xcode 26 SDK.)

### 5. iOS/legacy `NSItemProvider` / `UIPasteboard` instead of `Transferable` + `.dropDestination`

```swift
// ❌ WRONG — manual NSItemProvider callbacks (hop threads, fight Swift 6) and a type that doesn't exist on Mac
.onDrop(of: [.fileURL], isTargeted: nil) { providers in
    providers.first?.loadObject(ofClass: URL.self) { url, _ in /* off-main, isolation hazard */ }
    return true
}
UIPasteboard.general.string = "hi"   // ❌ UIPasteboard does NOT exist on macOS
```

```swift
// ✅ CORRECT — Transferable + .draggable / .dropDestination with a Sendable transferred type; NSPasteboard for raw clipboard
struct Note: Codable, Transferable {                                  // macOS 13.0+
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}
view.draggable(note)
    .dropDestination(for: Note.self) { notes, _ in handle(notes); return true }

NSPasteboard.general.clearContents()                                 // raw clipboard on macOS
NSPasteboard.general.setString("hi", forType: .string)
```

The manual `NSItemProvider` path is verbose, hops threads in its load callbacks, and fights Swift 6 isolation; `UIPasteboard` is iOS-only and won't even compile on Mac. The current SwiftUI idiom is the `Transferable` protocol with `.draggable` / `.dropDestination(for:)`, with a **`Sendable`** transferred type so the value crosses the drop's actor boundary cleanly. For raw clipboard access use `NSPasteboard.general`.

### 6. Assuming Hardened Runtime / notarization needs no extra entitlements

```text
❌ WRONG — Developer-ID app that loads plug-ins / uses a JIT (V8, embedded scripting) / injects,
           with Hardened Runtime OFF or no com.apple.security.cs.* exceptions
           → notarization fails, or the app crashes at launch with a code-signing error.
```

```xml
<!-- ✅ CORRECT — Hardened Runtime ON; add ONLY the cs.* exceptions you truly need (most apps need NONE).
     A JIT runtime (e.g. a bundled Node) is typically signed SEPARATELY with these before the bundle is re-signed: -->
<dict>
    <key>com.apple.security.cs.allow-jit</key>                       <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
</dict>
```

Developer-ID distribution requires the **Hardened Runtime**, which *tightens* defaults (no unsigned-dylib loading, no JIT, no `DYLD_*` injection) unless you opt back in with a specific `com.apple.security.cs.*` exception. Most apps need none. Codesigning / notarization specifics are out of scope for this skill — but the Hardened Runtime *entitlements* are squarely in scope for "why does my notarized build crash at launch." (Exact `com.apple.security.cs.*` page bodies were not scraped — verify against your Xcode 26 SDK.)

---

## Detection tells

Grep-able signals that this domain is broken:

- `URL(fileURLWithPath:` / `Data(contentsOf:` / a `FileManager` read or write against a **literal or user-typed path** with no preceding `fileImporter` / `NSOpenPanel` → mistake 1.
- A picked `URL` saved to `UserDefaults` / disk via `.path` **or** a plain `bookmarkData()` with **no `options: .withSecurityScope`** → mistake 2.
- A resolved/picked URL used with **no surrounding `startAccessingSecurityScopedResource()` … `stopAccessingSecurityScopedResource()`** (or a `start` with no balancing `stop`/`defer`) → mistake 2.
- File/network/bookmark APIs in use but **no `.entitlements` keys**, or `com.apple.security.app-sandbox` missing on a Mac App Store target → mistake 3.
- `loadTransferable` / `.task` touching a `@MainActor`-created picker item under Swift 6 → mistake 4 (look for *"Sending main actor-isolated value …"*).
- `NSItemProvider` `loadObject` / `loadDataRepresentation` callbacks, or **any `UIPasteboard`** reference, in macOS code → mistake 5.
- Developer-ID build with JIT / plug-in loading / injection but **Hardened Runtime off** and no `com.apple.security.cs.*` → mistake 6.

---

## Canonical pattern

Quote this round-trip verbatim — consent → security-scoped bookmark → re-access; entitlements; Transferable drag-drop; `NSPasteboard`.

```swift
// 1. Get a file ONLY through user consent (SwiftUI; AppKit's NSOpenPanel is equivalent).
.fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
    guard case let .success(url) = result else { return }
    try? persist(url)
}

// 2. Persist access across launches with a SECURITY-SCOPED bookmark.
func persist(_ url: URL) throws {
    let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
    UserDefaults.standard.set(bookmark, forKey: "file")
}
func reopen() throws -> String {
    let data = UserDefaults.standard.data(forKey: "file")!
    var stale = false
    let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope,
                      relativeTo: nil, bookmarkDataIsStale: &stale)
    guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
    defer { url.stopAccessingSecurityScopedResource() }
    return try String(contentsOf: url)
}

// 3. Entitlements (MyApp.entitlements):
//   com.apple.security.app-sandbox                     -> true   (required for App Store)
//   com.apple.security.files.user-selected.read-write  -> true   (or .read-only)
//   com.apple.security.network.client                  -> true   (only if you make requests)

// 4. Drag-drop with Transferable, Sendable-correct under Swift 6 (macOS 13.0+).
struct Note: Codable, Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}
view.draggable(note)
    .dropDestination(for: Note.self) { notes, _ in handle(notes); return true }

// 5. Clipboard on macOS is NSPasteboard, never UIPasteboard.
NSPasteboard.general.clearContents()
NSPasteboard.general.setString("hi", forType: .string)
```

**Rules:** (a) **files come from the user** — `fileImporter` / `fileExporter` or `NSOpenPanel` / `NSSavePanel`; never a hard-coded path. (b) **persistence needs a security-scoped bookmark** (`bookmarkData(options: .withSecurityScope)`) + ref-counted `start`/`stopAccessingSecurityScopedResource` (balance with `defer`). (c) **declare every entitlement you use and no more**; sandbox-on + missing file/network key = silent failure. (d) **drag-drop is `Transferable` + `.draggable` / `.dropDestination`** with a `Sendable` type — not `NSItemProvider`; move picker/transfer work into an `@Observable` model under Swift 6. (e) **clipboard is `NSPasteboard`** (no `UIPasteboard` on Mac). (f) **Hardened Runtime ON** for notarization; add `com.apple.security.cs.*` only if you JIT/load-plug-ins/inject.

macOS-specific: the sandbox lets a Mac app *reach out* (document/editor apps legitimately open files all over the disk) — but only via consent + bookmarks; iOS never does. Entitlements are granular and explicit on Mac, automatic and invisible on iOS. `NSOpenPanel` / `NSSavePanel` / `NSPasteboard` are AppKit Mac-only; SwiftUI's `fileImporter` / `fileExporter` wrap the panels. Drag-drop is pointer-driven and Finder-integrated. Hardened Runtime + notarization gate non-App-Store distribution — a step iOS never faces.

---

## Sources

| URL | Type | Confidence | Key fact / verbatim |
|---|---|---|---|
| https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox | primary-doc | high (page) / medium (body) | Canonical "user-driven access via open/save panel + security-scoped bookmarks" reference; sandbox grants the container plus user-selected files. Body JS-rendered, not verbatim-captured. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/foundation/url/bookmarkcreationoptions/withsecurityscope | primary-doc | high (symbol) / medium (body) | `.withSecurityScope` bookmark option — the flag that makes a bookmark re-grantable across launches. Symbol confirmed; body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox | primary-doc | high (symbol) / medium (body) | App Sandbox entitlement key — *"A Boolean value that indicates whether the app may use access control technology to contain damage…"* (Apple standard rendering). Symbol/page confirmed; body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/coretransferable/transferable | primary-doc | high (symbol) | `Transferable` protocol — current SwiftUI drag-drop / paste model. `macOS 13.0+`. Body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:) | primary-doc | high (symbol) | `.dropDestination(for:action:isTargeted:)` — the receive side, paired with `.draggable`. `macOS 13.0+`. Symbol confirmed. Accessed 2026-06-06. |
| https://www.hackingwithswift.com/example-code/system/how-to-use-security-scoped-bookmarks-to-access-the-file-system | practitioner | high | The canonical `bookmarkData(options: .withSecurityScope)` ↔ `startAccessingSecurityScopedResource()` round-trip, including the stale-bookmark re-create. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource() | primary-doc | high (symbol) | `startAccessingSecurityScopedResource()` returns a `Bool` grant and is **ref-counted** — each call must be balanced by one `stopAccessingSecurityScopedResource()`. Symbol confirmed; body JS-rendered. Accessed 2026-06-06. |
| https://www.reddit.com/r/swift/comments/1dk8ces/strict_concurrency_swift_6_causes/ | forum (lived) | high | Error verbatim *"Sending main actor-isolated value of type 'PhotosPickerItem' with later accesses to nonisolated context risks causing data races"*; fix: move the item + `loadTransferable` work into an `@Observable` view-model held as `@State`; *"The `.task()` is nonisolated … the PhotosPickerItem is isolated to mainactor."* Accessed 2026-06-06. |

**Carried UNVERIFIED flags** (scrape 2026-06-06): the Apple doc pages for App Sandbox file access, `com.apple.security.app-sandbox`, `.withSecurityScope`, `Transferable`, and `dropDestination` render their substantive bodies via JavaScript — **symbol names, page identities, and availability are confirmed, but verbatim body prose was not captured**; the exact `com.apple.security.cs.*` Hardened-Runtime entitlement bodies were likewise not scraped. Where exact prose, an entitlement string, or a `cs.*` key matters, **verify against your Xcode 26 SDK**.
