# Source directory — the VERIFY map (step 5)

The Apple/WWDC/practitioner sources for confirming an AppKit-interop fact. **Fetch Apple docs via Sosumi**
(`curl -sSL https://sosumi.ai/<path>`), never `WebFetch developer.apple.com` — protocol in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`. Pair every spec check with the **practice**
read: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` (+ `recipe nsview-bridge`,
`deprecated <api>`). Floors reconcile against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

## Sosumi paths (the `<apple-path>` after `https://sosumi.ai/`)

| API | Sosumi path | For defect |
|---|---|---|
| `NSViewRepresentable` | `documentation/swiftui/nsviewrepresentable` | interop-01/02/09 |
| `NSViewControllerRepresentable` | `documentation/swiftui/nsviewcontrollerrepresentable` | interop-04 |
| `NSHostingController` | `documentation/swiftui/nshostingcontroller` | interop-05 |
| `NSHostingView` | `documentation/swiftui/nshostingview` | interop-05/08 |
| `NSHostingSceneBridgingOptions` | `documentation/swiftui/nshostingscenebridgingoptions` | interop-08 |
| `NSHostingSizingOptions` | `documentation/swiftui/nshostingsizingoptions` | interop-10 |
| `NSHostingMenu` | `documentation/swiftui/nshostingmenu` | interop-10 |
| `NSAnimationContext.animate` | `documentation/appkit/nsanimationcontext/animate(_:changes:completion:)` | interop-10 |
| `NSVisualEffectView` | `documentation/appkit/nsvisualeffectview` | interop-07 |
| `acceptsFirstResponder` | `documentation/appkit/nsresponder/acceptsfirstresponder` | interop-03 |
| `makeFirstResponder(_:)` | `documentation/appkit/nswindow/makefirstresponder(_:)` | interop-03 |
| macOS 14 release notes | `documentation/macos-release-notes/macos-14-release-notes` | interop-08 (scene-bridge verbatim) |

## swiftui-ctx practice anchors

| Need | Command | Yields |
|---|---|---|
| the canonical bridge template | `swiftui-ctx recipe nsview-bridge` | the `make`/`update` skeleton + real permalinks (4,698 bridges) |
| the reverse-bridge ✅ | `swiftui-ctx lookup NSHostingController --json` | `consensus (rootView) 100%` + a permalinked `NSHostingController(rootView:)` example |
| a live enclosing body for `## Source` | `swiftui-ctx file <recommended.id> --smart` | the real `var body`/func from GitHub |
| deprecated-in-practice check | `swiftui-ctx deprecated <api> --json` | `replacement`/`migrate_to` + `doc` |

## Practitioner / WWDC corroboration

| URL | Type | For |
|---|---|---|
| https://developer.apple.com/videos/play/wwdc2022/10075/ | WWDC22 "Use SwiftUI with AppKit" | the sanctioned representable + Coordinator path |
| https://github.com/onmyway133/blog/issues/589 | practitioner | full focus-aware `NSViewRepresentable` |
| https://msena.com/posts/three-column-swiftui-macos/ | practitioner | `NSSplitViewController` via `NSViewControllerRepresentable` |
| https://www.donnywals.com/solving-main-actor-isolated-property-can-not-be-referenced-from-a-sendable-closure-in-swift/ | practitioner | the Swift-6 Sendable-closure fix (interop-06) |

## Sources

The Apple primary docs above (fetched via Sosumi), the WWDC22 session, and the named practitioner posts.
The `swiftui-ctx` CLI is the bundled practice corpus (1,857 macOS repos); Sosumi (https://sosumi.ai) is
the paired Apple-docs spec layer.
