# Newer bridge surfaces & their floors (interop-10)

`fix_mode: flag-only`, **hard-fail** when ungated under a target below the surface's floor. The classic
four (`NSViewRepresentable`, `NSViewControllerRepresentable`, `NSHostingController`, `NSHostingView`) are
`macOS 10.15+`. Later releases added bridges that solve long-standing rough edges — reach for these
instead of hand-rolling Auto Layout glue, hidden toolbars, or `CABasicAnimation`. **Each has a higher
floor; an ungated use under a lower deployment target is a build break.** Gate with
`if #available(macOS <floor>, *)` on the **macOS** arm (never `iOS` — see
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`).

| API | macOS floor | What it bridges |
|---|---|---|
| `NSHostingSizingOptions` (`.sizingOptions`) | 13.0 | feeds the SwiftUI view's measured size into Auto Layout (`.intrinsicContentSize`, `.minSize`, `.maxSize`) |
| `sizeThatFits(_:nsView:context:)` (optional representable member) | 13.0 | the *forward* direction: a representable proposes its own size to SwiftUI layout. **A macOS-12 target cannot use this** — fall back to `.frame`/intrinsic size |
| `NSHostingSceneBridgingOptions` / `.sceneBridgingOptions` | 14.0 | routes scene chrome (`.toolbars`, `.title`, `.all`, `[]`) from hosted SwiftUI up to the `NSWindow` (interop-08) |
| `NSHostingMenu(rootView:)` | **14.4** (corrects shipped doc's "14") | hosts a SwiftUI `Menu` body as an `NSMenu` (dock / context / status-item menu) |
| `NSAnimationContext.animate(_:changes:completion:)` | **15.0** (corrects shipped doc's "14") | drives AppKit view changes with a SwiftUI `Animation` (timing curves, springs) without dropping to `CAAnimation` |

> Two floors are **corrected** values, not the shipped doc figures: `NSHostingMenu` = **macOS 14.4** (doc
> says 14) and `NSAnimationContext.animate` = **macOS 15.0** (doc says 14). The reconciled truth is
> `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read it, never restate the table. All five
> are macOS-only and have no UIKit equivalent by these names; none replace the core `make…`/`update…`
> lifecycle — they extend it.

Detection: interop-10 fires only when ORIENT recorded a deployment target **below** the surface's floor
**and** the call is not wrapped in a `#available(macOS <floor>, *)` gate. If the target floor already
meets the surface floor, ignore.

## Sources

| URL | Type | Key fact |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/nshostingsizingoptions | primary-doc | option set (macOS 13+): `.intrinsicContentSize`, `.minSize`, `.maxSize`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nsviewrepresentable/sizethatfits(_:nsview:context:) | primary-doc | optional representable member (macOS 13+): proposes its own size to SwiftUI layout. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/nshostingmenu | primary-doc | *"An AppKit menu with custom content provided by a SwiftUI view hierarchy."* `init(rootView:)`; macOS 14.4+. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsanimationcontext/animate(_:changes:completion:) | primary-doc | macOS 15.0+: drives AppKit view changes with a SwiftUI `Animation`. Accessed 2026-06-07. |
