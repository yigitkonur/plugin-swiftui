# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
drawing/Canvas claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol (curl/CLI
commands + the JSON-404 caveat) is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the drawing-specific *map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The **practice** half of VERIFY is
`swiftui-ctx` (`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Absence from the SwiftUI index = treat as hallucinated until proven. Most APIs here are macOS
   12/10.15 — the only floor that *moves* is `MeshGradient` (macOS 15.0).
2. **Practice cross-check.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` →
   `consensus` (canonical call shape), `introduced_macos`, `recommended` (a real macOS-26 permalink for
   the finding's `## Source`), `co_occurs_with`. A `lookup` **exit 3** corroborates a hallucination.
3. Never `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess — fall back to Sosumi.

---

## A. SwiftUI drawing/Canvas symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`).

| Symbol | Path | Floor |
|---|---|---|
| `Canvas(opaque:colorMode:rendersAsynchronously:renderer:)` | `canvas` | 12.0 |
| `GraphicsContext` | `graphicscontext` | 12.0 |
| `TimelineView` | `timelineview` | 12.0 |
| `TimelineSchedule` (`.animation`/`.periodic`/`.explicit`) | `timelineschedule` | 12.0 |
| `Path` | `path` | 10.15 |
| `Circle`/`Ellipse`/`Rectangle`/`RoundedRectangle`/`Capsule` | `circle` · `ellipse` · `rectangle` · `roundedrectangle` · `capsule` | 10.15 |
| `Gradient`/`LinearGradient`/`RadialGradient`/`AngularGradient` | `gradient` · `lineargradient` · `radialgradient` · `angulargradient` | 10.15 |
| `MeshGradient(width:height:points:colors:)` | `meshgradient` | **15.0** |
| `View.drawingGroup(opaque:colorMode:)` | `view/drawinggroup(opaque:colormode:)` | 10.15 |
| `View.containerRelativeFrame(_:alignment:)` | `view/containerrelativeframe(_:alignment:)` | 14.0 |
| `GeometryReader` | `geometryreader` | 10.15 |
| `View.accessibilityChartDescriptor(_:)` | `view/accessibilitychartdescriptor(_:)` | 12.0 |

**Do not invent** (absent from the index → hallucinated): `Canvas2D`, `.canvasRenderer`,
`MeshGradientView`, `DrawingContext` (the real type is `GraphicsContext`). VERIFY any uncertain symbol via
a `swiftui-ctx lookup` exit-3 + Sosumi index-absence before emitting a hallucination finding.

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| Add Rich Graphics to your SwiftUI app (sample) | `documentation/swiftui/add_rich_graphics_to_your_swiftui_app` | `Canvas` + `TimelineView` together |
| Drawing paths and shapes (tutorial) | `tutorials/swiftui/drawing-paths-and-shapes` | `Path`, `Shape` conformance, control points |
| HIG — VoiceOver / accessibility | `design/human-interface-guidelines/accessibility` | descriptor intent for custom drawings (defer detail to `audit-swiftui-accessibility`) |

## C. WWDC sessions (`developer.apple.com/videos/play/<id>`)

| id | Title | Covers |
|---|---|---|
| `wwdc2021/10021` | Add rich graphics to your SwiftUI app | `Canvas`, `TimelineView`, immediate-mode drawing |
| `wwdc2024/10151` | Create custom visual effects with SwiftUI | `MeshGradient`, layer/visual effects |
| `wwdc2023/10160` | Animate with springs | timing context for `TimelineView`-driven motion |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| Paul Hudson / Hacking with Swift | `hackingwithswift.com/quick-start/swiftui` (Canvas, TimelineView, Path) | usage shape of `Canvas`/`TimelineView`/`Path` | high |
| Apple sample code | `github.com/apple` SwiftUI samples | `Canvas`+`TimelineView` patterns | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- swiftui-ctx practice CLI: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md` (run
  `lookup Canvas|TimelineView|MeshGradient|drawingGroup --json`, accessed 2026-06-07).
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
