# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
pointer/gesture claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the
curl/CLI commands and the JSON-404 caveat is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this file is the pointer/gesture-specific
*map* of which pages to fetch. Floor values live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the practice layer (consensus + permalinks)
is `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi + swiftui-ctx references)

1. **Does it exist / its macOS floor?** Fetch `https://sosumi.ai/documentation/swiftui/<symbol-path>` and
   read the `**Available on:** … macOS N+ …` line. Absence from the SwiftUI index = treat as
   stale/invented until proven (pg-01).
2. **Is it deprecated in practice?** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx deprecated <api>` →
   `deprecated`/`migrate_to` (pg-08/09). A `lookup` **exit 3** corroborates pg-01.
3. **What's the canonical shape?** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <api> --json` →
   `consensus` + `recommended` permalink; `file <recommended.id> --smart` for the real enclosing body.
4. Never `WebFetch` `developer.apple.com`; never paper a 404 with a memory guess.

---

## A. SwiftUI pointer/gesture symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`). Floors
per floors-master (re-confirmed 2026-06-07).

| Symbol | Path | macOS floor |
|---|---|---|
| `onHover(perform:)` | `view/onhover(perform:)` | 10.15+ |
| `onContinuousHover(coordinateSpace:perform:)` | `view/oncontinuoushover(coordinatespace:perform:)` | 14.0+ |
| `pointerStyle(_:)` | `view/pointerstyle(_:)` | 15.0+ (macOS-only, no iOS arm) |
| `PointerStyle` (cases `.grabActive`/`.grabIdle`/`.link`/`.zoomIn`/`.zoomOut`/`.columnResize`/`.rowResize`/`.frameResize(position:directions:)`) | `pointerstyle` | 15.0+ |
| `contextMenu(menuItems:)` | `view/contextmenu(menuitems:)` | 10.15+ (**deprecated** → prefer `contextMenu(menuItems:preview:)` macOS 13.0+) |
| `DragGesture` | `draggesture` | 10.15+ |
| `MagnifyGesture` | `magnifygesture` | 14.0+ |
| `RotateGesture` | `rotategesture` | 14.0+ |
| `SpatialTapGesture` | `spatialtapgesture` | 13.0+ |
| `@GestureState` | `gesturestate` | n/a (wrapper) |
| `.simultaneousGesture(_:)` / `.highPriorityGesture(_:)` | `view/simultaneousgesture(_:including:)` · `view/highprioritygesture(_:including:)` | 10.15+ |
| `SimultaneousGesture` / `ExclusiveGesture` / `.sequenced(before:)` | `simultaneousgesture` · `exclusivegesture` · `gesture/sequenced(before:)` | 10.15+ |

**Stale / invented (never emit):** `PointerStyle.grabbing` (→ `.grabActive`/`.grabIdle`).
**Real-but-deprecated (26.5):** `MagnificationGesture` (→ `MagnifyGesture`), `RotationGesture` (→
`RotateGesture`).

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| HIG — Pointing devices | `design/human-interface-guidelines/pointing-devices` (verify exact path) | cursor affordances; resize/grab cursors; pointer feedback expectations |
| HIG — Gestures | `design/human-interface-guidelines/gestures` (verify exact path) | Mac gesture vocabulary; right-click as a primary interaction |
| Adding interactivity with gestures | `documentation/swiftui/adding-interactivity-with-gestures` | `@GestureState`/`.updating`; composing gestures (simultaneous/exclusive/sequenced) |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| Session | Covers |
|---|---|
| WWDC — "What's new in SwiftUI" (per year) | gesture API renames (`MagnifyGesture`/`RotateGesture`), pointer modifiers |
| WWDC — pointer/cursor design sessions | `pointerStyle`, cursor affordances on the Mac |

> WWDC ids drift year to year — resolve the exact id via the session index before citing; treat the video
> as corroboration, the doc page (via Sosumi) as the spec.

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | Reliable for | Trust |
|---|---|---|
| SerialCoder.dev — macOS SwiftUI tutorials | pointer/focus affordances on macOS | medium |
| swiftui-ctx corpus (`lookup`/`deprecated`/`file --smart`) | real consensus shapes + permalinked macOS examples (the PRACTICE half) | high |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- swiftui-ctx CLI contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07); floors cross-checked
  against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.
- Practitioner sources as listed (trust labelled; corroboration only).
