# Reference — Toolbar Placements & Titles (nav-05/06/07/10/11)

macOS has **no navigation bar** — toolbar items use **semantic** placements and the title shows in the
**window titlebar**. iOS-bar concepts are deprecated, platform-absent, or no-ops on the Mac. **Floor
values are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — never
restated here**; the platform-wrong-placement list is `hallucination-blacklist.md` §5. Every ✅ shape is
the **swiftui-ctx consensus** (run the `lookup` in step VERIFY), not opinion.

---

## nav-05 · `.topBarLeading` / `.topBarTrailing` on a Mac target (hard-fail · auto)

The nominal replacements for the deprecated iOS placements — `topBarLeading` / `topBarTrailing` — are
**unavailable on macOS at all**. macOS is **absent** from Apple's platform list for those cases, so
referencing them on a Mac target is a compile-time *unavailable* error, not just an "iOS-shaped" choice.
Per `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`: a `macOS ABSENT` symbol is **replaced,
never wrapped in `#available(macOS …)`**. A `swiftui-ctx lookup` exit-3 on these corroborates that no
shipping Mac app uses them.

## nav-06 · `.navigationBarLeading` / `.navigationBarTrailing` (hard-fail · auto)

Deprecated (macOS 11.0+; exact deprecation version is `verify-SDK` per `floors-master.md`) **and iOS-only
to begin with**. Replace with a semantic placement.

## nav-07 · `navigationBarTitle` / `navigationBarTitleDisplayMode` (hard-fail · auto)

macOS has no navigation *bar*; the title shows in the **window titlebar** (plus the Windows menu and
Mission Control). The current cross-platform modifier is `navigationTitle(_:)` (macOS 11.0+).
`navigationBarTitleDisplayMode` and its `.inline`/`.large` modes are iOS/watchOS-only and **no-ops on the
Mac** (`hallucination-blacklist.md` §5).

```swift
// ❌ deprecated iOS-only, topBar* won't compile, iOS-bar title is a no-op
.toolbar {
    ToolbarItem(placement: .navigationBarLeading)  { Button("Back") {} }  // nav-06 deprecated iOS-only
    ToolbarItem(placement: .topBarTrailing)        { Button("Add")  {} }  // nav-05 unavailable → compile error
}
.navigationBarTitle("Inbox")                                              // nav-07 iOS bar concept
.navigationBarTitleDisplayMode(.inline)                                   // nav-07 no-op on macOS
```
```swift
// ✅ semantic placements + navigationTitle — SwiftUI positions per-platform on macOS
.toolbar {
    ToolbarItem(placement: .navigation)    { Button("Back") {} }   // leading, ahead of the title
    ToolbarItem(placement: .principal)     { TitleView() }         // centered on macOS
    ToolbarItem(placement: .primaryAction) { Button("Add")  {} }   // LEADING EDGE on macOS (not trailing)
    ToolbarItem { Button("Toggle") {} }                            // .automatic default
}
.navigationTitle(item?.name ?? "Untitled")    // → window titlebar / Windows menu / Mission Control
.navigationSubtitle("\(unread) unread")       // secondary line; macOS 11.0+ (iOS floor 26.0 — much higher)
```

**Semantic placements resolve on macOS as:** `.navigation` → leading (ahead of the inline title);
`.primaryAction` → **leading edge of the toolbar** (Apple: *"In macOS … the location for the primary
action is the leading edge of the toolbar"*) — NOT trailing; `.principal` and `.status` → **centered**.
`NavigationSplitView` adds a sidebar toggle automatically on macOS 14+; `ToolbarDefaultItemKind.sidebarToggle` (macOS 14.0+, `static let sidebarToggle: ToolbarDefaultItemKind`) is the identity token used with `toolbar(removing: .sidebarToggle)` to remove that default toggle — it is not a `ToolbarItemPlacement`. No first-party inspector-toggle item kind exists on any SwiftUI type; toggle the inspector via its `.inspector(isPresented:)` binding instead.

**swiftui-ctx grounding (run live in VERIFY):** `lookup toolbar --json` →
`consensus: [{shape:"{ }", pct:89}]`, `co_occurs_with: ["ToolbarItem","ToolbarItemGroup","searchToolbarBehavior", …]`,
`recommended` a high-authority macOS-26 `.toolbar { … }` example (permalinked `var body`). The 89%
trailing-closure `{ }` form is the canonical toolbar shape; the auto-fix's ✅ in `## Correct` is that
consensus shape backed by `file <recommended.id> --smart`.

## nav-10 · `.searchable` on a column, not the split view (advisory)

`.searchable` goes on the `NavigationSplitView` itself, **not** on a column — otherwise it lands in the
wrong toolbar slot on macOS. `searchToolbarBehavior(_:)` (macOS 26.0+) tunes the field; gate it if the floor is below 26. Note: `.minimize` is **not available on macOS** (iOS/iPadOS/Mac Catalyst/visionOS 26.0+ only); the macOS-safe case is `.automatic`.

```swift
// ✅ searchable on the split view (right toolbar slot)
NavigationSplitView { SidebarView() } detail: { DetailView() }
    .searchable(text: $query)
```

## nav-11 · `ToolbarSpacer` / `SpacerSizing` ungated under a < macOS 26 floor (hard-fail · flag)

`ToolbarSpacer(_:placement:)` + `SpacerSizing` (`.fixed` for a single system-standard gap, `.flexible`
to push items toward opposite ends of a region) are **macOS 26.0+**. Under a deployment target below 26
they must sit behind `#available(macOS 26, *)` (the macOS arm — see
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`). If the project floor is already ≥ 26,
nav-11 does not fire — read the floor in ORIENT.

```swift
if #available(macOS 26, *) {
    ToolbarSpacer(.fixed, placement: .primaryAction)      // system-standard gap
    ToolbarSpacer(.flexible, placement: .primaryAction)   // pushes following items apart
}
```

The `ToolbarSpacer` *glass era* crosses into `audit-swiftui-liquid-glass` — gate it here, cross_ref the
glass-adoption angle there.

---

## Sources

All Apple docs fetched via Sosumi (protocol:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`); access 2026-06-07. Floors live in
`floors-master.md`; the live consensus shape + permalink come from `swiftui-ctx lookup toolbar` (see
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`).

- `ToolbarItemPlacement` (`.primaryAction` = leading edge on macOS; `.principal`/`.status` centered; `navigationBarLeading`/`Trailing` deprecated iOS-only; `topBarLeading`/`topBarTrailing` unavailable on macOS): https://developer.apple.com/documentation/swiftui/toolbaritemplacement
- `ToolbarSpacer` + `SpacerSizing` (macOS 26; `.fixed`/`.flexible` toolbar gaps): https://developer.apple.com/documentation/swiftui/toolbarspacer
- `navigationTitle(_:)` (macOS → window titlebar / Windows menu / Mission Control): https://developer.apple.com/documentation/swiftui/view/navigationtitle(_:)-43srq
- `navigationSubtitle(_:)` (macOS 11.0+, also iOS/iPadOS 26.0+): https://developer.apple.com/documentation/swiftui/view/navigationsubtitle(_:)
- `searchable(text:placement:prompt:)`: https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:prompt:)-18a8f
- `searchToolbarBehavior(_:)` (macOS 26.0+; `.minimize` is iOS/iPadOS/Mac Catalyst/visionOS 26.0+ only — not macOS; macOS-safe case is `.automatic`): https://developer.apple.com/documentation/swiftui/view/searchtoolbarbehavior(_:)
