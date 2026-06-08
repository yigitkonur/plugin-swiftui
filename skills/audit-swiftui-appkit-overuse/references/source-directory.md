# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
overuse claim (does the SwiftUI replacement exist? at this floor? does it cover the AppKit control's
behavior?). **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the overuse-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the SwiftUI replacement exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Also run `swiftui-ctx lookup <api> --json` for the practice-side `introduced_macos` + consensus
   shape; a `lookup` exit-3 (not-found) means the name is unused in shipping Mac apps — re-check it.
2. **Does it cover the AppKit control's behavior?** Read the SwiftUI doc's modifiers + the
   `co_occurs_with` list from `swiftui-ctx`. If a capability is missing (rich-text layout, behind-window
   vibrancy, hierarchical columns), the bridge may be a justified hatch, not overuse.
3. **Never `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.** Fall back to
   Sosumi (it never 404s on a valid human URL).

## A. SwiftUI replacement-symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).

| Replaces (AppKit) | SwiftUI symbol | Path |
|---|---|---|
| `NSButton` / `NSSwitch` | `Button` · `Toggle` | `button` · `toggle` |
| `NSTextField` / `NSTextView` (26) | `TextField` · `TextEditor` | `textfield` · `texteditor` |
| `NSSlider` / `NSStepper` | `Slider` · `Stepper` | `slider` · `stepper` |
| `NSColorWell` / `NSDatePicker` | `ColorPicker` · `DatePicker` | `colorpicker` · `datepicker` |
| `NSProgressIndicator` | `ProgressView` · `Gauge` | `progressview` · `gauge` |
| `NSPopUpButton`/`NSComboBox`/`NSSegmentedControl` | `Picker` | `picker` |
| `NSStatusItem` | `MenuBarExtra` | `menubarextra` |
| `NSOpenPanel`/`NSSavePanel` | `fileImporter`/`fileExporter` | `view/fileimporter(ispresented:allowedcontenttypes:oncompletion:)` |
| `NSItemProvider`/`NSPasteboard` | `Transferable` + `.draggable`/`.dropDestination` | `coretransferable/transferable` (CoreTransferable) |
| `NSGlassEffectView` | `.glassEffect(_:in:)` | `view/glasseffect(_:in:)` |

## B. AppKit pages (confirm an escape hatch is genuinely beyond SwiftUI)

| Page | Path |
|---|---|
| `NSTextView` (rich-text engine) | `documentation/appkit/nstextview` |
| `NSOutlineView` (hierarchical source list) | `documentation/appkit/nsoutlineview` |
| `NSVisualEffectView` (behind-window vibrancy) | `documentation/appkit/nsvisualeffectview` |
| `NSViewRepresentable` (the bridge contract) | `documentation/swiftui/nsviewrepresentable` |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2022/10075 | Use SwiftUI with AppKit | bridge only the piece that needs it; prefer native SwiftUI |
| wwdc2023/10148 | What's new in SwiftUI | `MenuBarExtra` window style, `Transferable` ergonomics |
| wwdc2025/256 | What's new in SwiftUI | macOS-26 rich-text `TextEditor`; native surfaces that retire bridges |

## D. Practitioners (corroboration only — never primary; label `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| swiftui-ctx `recipe menubar-app` | (bundled CLI) | the real `MenuBarExtra` pattern + permalinks | high |
| swiftui-ctx `recipe draggable-reorder` | (bundled CLI) | the `Transferable` drag/drop pattern | high |
| swiftui-ctx `recipe nsview-bridge` | (bundled CLI) | what a real bridge wraps (judge overuse vs justified) | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- swiftui-ctx CLI contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
