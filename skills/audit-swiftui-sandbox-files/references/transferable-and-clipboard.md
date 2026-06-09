# Transferable, Drag-Drop & Clipboard (sf-05 · sf-06 · sf-07 · sf-08)

The current SwiftUI idiom for moving values in/out of an app is the **`Transferable`** protocol (macOS
13.0+) with `.draggable` / `.dropDestination` and a **`Sendable`** transferred type, plus `NSPasteboard`
for the raw clipboard. AI trained on iOS-shaped, pre-Swift-6 data reaches instead for manual
`NSItemProvider` callbacks (which hop threads and fight Swift 6 isolation) and `UIPasteboard` (which **is
absent from native macOS**; Mac Catalyst 13.1+ carries it — this skill is native macOS only).

> Seam: the `loadTransferable` Swift-6 **Sendable race** is owned by
> `audit-swiftui-concurrency-safety` (isolation fix); this skill owns only the **file-consent** angle and
> `cross_ref`s it (sf-07). The `dropDestination(for:action:isTargeted:)` **deprecation flag** is owned by
> `audit-swiftui-api-currency`; this skill flags it where it sits in a drag-drop pipeline and `cross_ref`s
> currency (sf-08).

---

## sf-05 — `UIPasteboard` on Mac (won't compile)

```swift
UIPasteboard.general.string = "hi"   // ❌ UIPasteboard is absent from native macOS (Mac Catalyst 13.1+ carries it)
```

```swift
// ✅ CORRECT — the clipboard on macOS is NSPasteboard
NSPasteboard.general.clearContents()
NSPasteboard.general.setString("hi", forType: .string)
```

`UIPasteboard` is absent from native macOS (Mac Catalyst 13.1+ carries it) and won't compile in a native SwiftUI macOS target. This is the one **`fix_mode: auto`** defect in
the domain: a mechanical `UIPasteboard.general.string = X` → `NSPasteboard.general.clearContents();
NSPasteboard.general.setString(X, forType: .string)` rewrite. A `swiftui-ctx lookup UIPasteboard` on the
macOS corpus returns **exit 3** (no shipping Mac app uses it) — corroborating the platform-wrong finding.

---

## sf-06 — manual `NSItemProvider` / `.onDrop` instead of `Transferable`

```swift
// ❌ WRONG — manual NSItemProvider callbacks (hop threads, fight Swift 6) and a type that doesn't exist on Mac
.onDrop(of: [.fileURL], isTargeted: nil) { providers in
    providers.first?.loadObject(ofClass: URL.self) { url, _ in /* off-main, isolation hazard */ }
    return true
}
```

```swift
// ✅ CORRECT — Transferable + .draggable / .dropDestination with a Sendable transferred type
struct Note: Codable, Transferable {                                  // macOS 13.0+
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}
view.draggable(note)
    .dropDestination(for: Note.self) { notes, _ in handle(notes); return true }
```

The manual `NSItemProvider` path is verbose, hops threads in its load callbacks, and fights Swift 6
isolation. The current idiom is `Transferable` + `.draggable` / `.dropDestination(for:)` with a
**`Sendable`** transferred type so the value crosses the drop's actor boundary cleanly. `swiftui-ctx
lookup dropDestination` reports the consensus drop shape (`(for)` at 87%) and a `recommended` permalinked
example; fetch it with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart`.

---

## sf-07 — `loadTransferable` picker item across an actor boundary (file-consent angle)

```swift
// ❌ Compiles pre-Swift-6, errors under the Swift 6 language mode
struct AddView: View {
    @State private var item: PhotosPickerItem?
    var body: some View {
        SomeView().task {
            let data = try? await item?.loadTransferable(type: Data.self)  // ❌ Swift 6 data-race
        }
    }
}
// error: "Sending main actor-isolated value of type 'PhotosPickerItem' with later accesses
//         to nonisolated context risks causing data races"
```

```swift
// ✅ CORRECT — own the item + the async work in an @Observable model held as @State
@Observable @MainActor final class PhotoLoader {
    var item: PhotosPickerItem?
    func load() async -> Data? { try? await item?.loadTransferable(type: Data.self) }
}
struct AddView: View {
    @State private var loader = PhotoLoader()
    var body: some View { SomeView().task { _ = await loader.load() } }
}
```

A main-actor-isolated value (a `PhotosPickerItem` born in a `@MainActor` view) read inside the
*nonisolated* `.task`/transfer closure is a hard error under Swift 6 strict concurrency. The fix is to
**move the state and the transfer work into a model** (created as `@State`), not to sprinkle
`MainActor.run`. **This isolation fix is owned by `audit-swiftui-concurrency-safety`** — when the hazard
is present, emit the finding with `cross_ref: audit-swiftui-concurrency-safety`; the file-consent
question (did the picked item's data ever get persisted with a bookmark?) is this skill's part. A fresh
Xcode 26 target may ship *Default Actor Isolation = Main Actor* (`-default-isolation MainActor`), which can
pre-isolate and mask this — never assume that mode is on; it is opt-in. Carry that assumption as
`advisory`/`verify against Xcode 26 SDK`.

---

## sf-08 — deprecated 3-arg `dropDestination` (macOS 26.5)

```swift
view.dropDestination(for: Note.self) { items, location in   // (for:action:isTargeted:) — 3-arg Bool-returning
    handle(items); return true
}
```

`dropDestination(for:action:isTargeted:)` (the 3-arg, Bool-returning form) is **deprecated in macOS 26.5**
→ `dropDestination(for:isEnabled:action:)` (the macOS-26.0+ successor). Per
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`, the successor floors at macOS 26.0. Note the
action closure signature changed: the deprecated form uses `([T], CGPoint) -> Bool`; the successor uses
`([T], DropSession) -> Void` (second parameter `CGPoint` → `DropSession`; return `Bool` → `Void`). The
**deprecation flag is owned by `audit-swiftui-api-currency`**; flag it here where it sits in a drag-drop
pipeline and `cross_ref: audit-swiftui-api-currency`. Carry as **advisory**.

> **Corpus-vs-spec note (honesty).** `swiftui-ctx lookup dropDestination` / `deprecated dropDestination`
> currently report `deprecated: false` — the 1,857-app catalog was parsed against the macOS 26.5 SDK but
> **predates the 26.5 doc revision** that records the deprecation, so the corpus hasn't caught up. When
> the corpus and `floors-master.md` disagree, **floors-master wins** (failure protocol): treat the
> deprecation as fact and note the catalog lag in the finding's `## Evidence`.

---

## macOS clipboard / drag-drop facts

- The clipboard on macOS is **`NSPasteboard`** (AppKit, Mac-only); `UIPasteboard` is iOS-only.
- `NSOpenPanel` / `NSSavePanel` / `NSPasteboard` are AppKit Mac-only; SwiftUI's `fileImporter` /
  `fileExporter` wrap the panels. Drag-drop is pointer-driven and Finder-integrated on the Mac.

---

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://developer.apple.com/documentation/coretransferable/transferable | primary-doc | high (symbol) | `Transferable` protocol — current SwiftUI drag-drop/paste model. macOS 13.0+. Body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftui/view/draggable(_:) | primary-doc | high (symbol) | `.draggable(_:)` — the source side, macOS 13.0+. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:) | primary-doc | high (symbol) | The 3-arg `.dropDestination(for:action:isTargeted:)` — paired with `.draggable`; **deprecated macOS 26.5** → `dropDestination(for:isEnabled:action:)` (successor macOS 26.0+, per floors-master). Accessed 2026-06-06. |
| https://developer.apple.com/documentation/appkit/nspasteboard | primary-doc | high (symbol) | `NSPasteboard.general` — the raw clipboard on macOS; `UIPasteboard` has no Mac arm. Accessed 2026-06-06. |
| https://www.reddit.com/r/swift/comments/1dk8ces/strict_concurrency_swift_6_causes/ | forum (lived) | high | Error verbatim *"Sending main actor-isolated value of type 'PhotosPickerItem' …"*; fix = move the item + `loadTransferable` into an `@Observable` view-model held as `@State`; *"The `.task()` is nonisolated … the PhotosPickerItem is isolated to mainactor."* Accessed 2026-06-06. |
| swiftui-ctx `lookup dropDestination` / `deprecated dropDestination` (corpus of 1,857 macOS apps) | practice | high | consensus drop shape `(for)` 87%; `introduced_macos: 13.0`; corpus reports `deprecated: false` (**predates the 26.5 doc** — floors-master is authoritative); `doc:` https://sosumi.ai/documentation/swiftui/view/dropdestination. Run 2026-06-07. |

Floors are cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
(`Transferable`/`draggable`/`dropDestination(3-arg)` macOS 13.0+; `dropDestination(for:isEnabled:action:)`
macOS 26.0+; the 26.5 deprecation) and the platform-wrong list in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`; pages fetched via Sosumi (access
2026-06-07). Apple doc bodies render via JavaScript — symbols and availability confirmed; where exact body
prose or a Swift-6 build setting matters, **verify against Xcode 26 SDK**.
