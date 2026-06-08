# Reference — System & Scene Bridges (over-02, over-03, over-04, over-06)

The system-level AppKit affordances that AI reaches for out of habit when SwiftUI ships a native scene
or modifier. Each is overuse when its SwiftUI equal exists at the floor. The ✅ in a finding is the
swiftui-ctx consensus shape + a real permalink, not a hand-written snippet.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## over-02 — `NSStatusItem` → `MenuBarExtra` scene (macOS 13+)

A hand-built `NSStatusBar.system.statusItem(...)` + an `NSMenu` (or an `NSPopover` driven by the status
button) is the classic pre-SwiftUI menu-bar pattern. Since macOS 13, `MenuBarExtra` is a **Scene** — it
owns the status item, its label, and its content window for you; `.menuBarExtraStyle(.window)` gives the
popover form. Bridge only if you need something `MenuBarExtra` genuinely can't express (rare).

**swiftui-ctx grounding (run during this build, 2026-06-07):**
`swiftui-ctx lookup MenuBarExtra --json` → `deprecated: false`; consensus shapes **`{ }` (50%)**,
**`(_, systemImage)` (29%)**; `co_occurs_with` includes `menuBarExtraStyle`, `SettingsLink`,
`windowLevel`. `recommended` = `ex_259054c919`, `min_macos: 26`, shape `{ }`, permalink
`https://github.com/kageroumado/phosphene/blob/757cae705aaf36ac13ba973919a181ea89fb2e3c/Phosphene/PhospheneApp.swift#L11`
(repo `kageroumado/phosphene`). Use `swiftui-ctx recipe menubar-app` for the full pattern. Put that
permalink in `## Source` and the `{ }` / `(_, systemImage)` consensus shape in `## Correct`.

The scene-level **activation / window-placement** traps of `MenuBarExtra` belong to
`audit-swiftui-scenes-windows` — cross_ref it; don't audit them here.

## over-03 — `NSOpenPanel` / `NSSavePanel` → `fileImporter` / `fileExporter` / `fileMover`

A simple "pick a file to open" / "choose where to save" needs no `NSOpenPanel`. SwiftUI's
`.fileImporter(isPresented:allowedContentTypes:onCompletion:)`,
`.fileExporter(...)`, and `.fileMover(...)` present the same panels and return security-scoped URLs.

**swiftui-ctx grounding (2026-06-07):** `swiftui-ctx lookup fileImporter --json` → consensus
**`(isPresented, allowedContentTypes, allowsMultipleSelection)` (65%)**,
**`(isPresented, allowedContentTypes)` (23%)**; `recommended` = `ex_b884986158`, `min_macos: 26`,
permalink `https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/MainScreen.swift#L26`
(repo `sindresorhus/Gifski`, 8409★). `fileImporter` is macOS 11.0+ — confirm the floor before flagging.

The **security-scoped-bookmark** correctness (`startAccessingSecurityScopedResource`, persisting access)
once `fileImporter` is in place is `audit-swiftui-sandbox-files` — cross_ref it.

## over-04 — `NSItemProvider` / `NSPasteboard.writeObjects` → `Transferable`

For drag/drop and copy/paste of a **model type**, `Transferable` conformance + `.draggable(_:)`,
`.dropDestination(for:isEnabled:action:)` (macOS 26+; `.dropDestination(for:action:isTargeted:)` is deprecated), `.copyable(_:)` / `.pasteDestination(for:action:validator:)` is the native path; you almost
never need to hand-pack an `NSItemProvider` or write to `NSPasteboard` directly in SwiftUI. Use
`swiftui-ctx recipe draggable-reorder` for the `Transferable` pattern + real examples. (`Transferable`
is a conformance, so `lookup` redirects to the recipe.) Bridging raw pasteboard is justified only for a
legacy/heterogeneous flavor SwiftUI's `UTType` model can't express — note that explicitly. cross_ref
`sandbox-files` for drag-payload/consent correctness.

## over-06 — whole-window / large-subtree bridges

Two shapes:
- **Reverse bridge in a SwiftUI-first app** — `NSHostingView`/`NSHostingController` hosting the *entire*
  window content under a hand-built `NSWindow`. In a SwiftUI-first app a `WindowGroup`/`Window` scene
  removes the `NSWindow` plumbing entirely (and `.searchable` only works inside a real SwiftUI scene —
  see `audit-swiftui-appkit-interop` mistake 8). cross_ref `scenes-windows`.
- **Over-wrapped representable** — a `makeNSView` returning a composed `NSStackView` / container that
  lays out several controls. That is several over-01 controls plus AppKit layout; prefer a SwiftUI
  `VStack`/`Form` of native controls and bridge nothing.

(`NSHostingController`/`NSHostingView` are the *correct* bridge in a genuinely AppKit-first app —
over-06 is about a SwiftUI-first app reaching for them needlessly. READ to confirm which app shape you
are in before flagging.)

## VERIFY + floors

Confirm each replacement's floor before flagging:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (`MenuBarExtra` 13, `fileImporter` 11,
`Transferable`/`.draggable` 13). Fetch protocol + paths: `references/source-directory.md` +
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`. CLI contract:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

---

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://developer.apple.com/documentation/swiftui/menubarextra | primary-doc | high | `MenuBarExtra` Scene — macOS 13.0+; owns the status item + label + content window. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:) | primary-doc | high | `.fileImporter` — macOS 11.0+; presents the open panel, returns security-scoped URLs. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:) | primary-doc | high | `.fileExporter` — native save-panel replacement. macOS 11.0+. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/coretransferable/transferable | primary-doc | high | `Transferable` — the drag/drop/clipboard model; `.draggable`/`.dropDestination` macOS 13.0+. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nshostingview | primary-doc | high | Reverse bridge; correct only when hosting SwiftUI in a genuinely AppKit-owned window. Accessed 2026-06-07. |
