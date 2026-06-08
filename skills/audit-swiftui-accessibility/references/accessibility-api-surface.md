# Accessibility API surface — the allow-list, the invented names, the legacy combinator (a11y-10/11)

The name/existence authority for the accessibility domain. Floor *values* are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the canonical invented-name list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate. For the
**canonical call shape** of any modifier below, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup
<api> --json` and read its `consensus` + `recommended` permalink instead of pasting a static snippet.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

## A. Real SwiftUI accessibility modifiers (allow-list)

| Modifier / type | macOS floor | Notes |
|---|---|---|
| `accessibilityLabel(_:)` (string `StringProtocol`) | 11.0 | the announced name; `LocalizedStringResource` overload = 13.0; closure form `accessibilityLabel(content:)` = 15.0 |
| `accessibilityValue(_:)` | 11.0 | current value of a custom control; closure form `(_:isEnabled:)` = 15.0 |
| `accessibilityHint(_:)` | 13.0 | what an action does |
| `accessibilityHidden(_:)` | 11.0 | hide decorative elements from VoiceOver |
| `accessibilityElement(children:)` | 10.15 | `.combine` / `.ignore` / `.contain` — group a composite |
| `accessibilityAddTraits(_:)` / `accessibilityRemoveTraits(_:)` | 11.0 | `.isButton`, `.isToggle`(14.0), `.isHeader`, `.isImage`, `.isSelected` |
| `accessibilityFocused(_:)` + `AccessibilityFocusState` | 12.0 | VoiceOver focus (NOT keyboard `@FocusState`) |
| `accessibilitySortPriority(_:)` | 11.0 | reading order within a container |
| `accessibilityChartDescriptor(_:)` | 12.0 | Audio Graph for a `Chart` |
| `accessibilityRepresentation(representation:)` | 12.0 | proxy a custom view with a standard control's semantics |
| `@Environment(\.accessibilityReduceMotion)` | 10.15 | read to branch motion off |
| `@Environment(\.accessibilityDifferentiateWithoutColor)` | 10.15 | read to add a non-color cue |

`consensus` for `accessibilityLabel` is **100% `(_)`** (the trailing-string shape); `accessibilityElement`
is **95% `(children:)`** — both confirmed via `swiftui-ctx lookup` (2026-06-07).

## B. a11y-10 — invented names (hard-fail, fix_mode: auto)

These do **not** exist; a `swiftui-ctx lookup` returns **exit 3** with a did-you-mean `suggestion`.

| ❌ Invented | ✅ Real |
|---|---|
| `.voiceOverLabel("…")` / `.a11yLabel("…")` / `.screenReaderLabel("…")` / `.accessibilityName("…")` | `.accessibilityLabel("…")` |
| `.accessibilityText("…")` | `.accessibilityLabel("…")` (or `.accessibilityValue` if it's a value) |
| `.voiceOverHint("…")` | `.accessibilityHint("…")` |

Verified: `swiftui-ctx lookup voiceOverLabel` → `not_found`, suggestion `chartOverlay, overlay, …` (2026-06-07).
Cross-check any candidate against `_shared/hallucination-blacklist.md` before emitting.

## C. a11y-11 — the legacy combined modifier (warning, fix_mode: auto)

The pre-iOS-13.4 combinator bundled label/hint/traits/value into one `.accessibility(...)` call. Split it:

```
// ❌ legacy combined
.accessibility(label: Text("Add"), hint: Text("Adds a row"))
.accessibility(addTraits: .isButton)
// ✅ per-aspect modifiers (current)
.accessibilityLabel("Add")
.accessibilityHint("Adds a row")
.accessibilityAddTraits(.isButton)
```

`.accessibility(identifier:)` → `.accessibilityIdentifier(_:)` (test-only id, not user-facing).
**Confirmed deprecated: `macOS 10.15–26.5 Deprecated`** — Apple docs confirm the `@available(…, deprecated:)`
annotation; replacement is `accessibilityLabel(_:)`. The sibling combinators (`accessibility(hint:)`,
`accessibility(value:)`, `accessibility(hidden:)`, `accessibility(identifier:)`, `accessibility(addTraits:)`,
`accessibility(removeTraits:)`, `accessibility(sortPriority:)`) are deprecated likewise. The corpus
`deprecated:false` was a false negative. Carry a11y-11 as `source: macOS 10.15–26.5 Deprecated →
accessibilityLabel(_:)`. The split rewrite is behavior-preserving regardless, so the auto-fix is safe under
the fix-safety protocol.

## Sources

- Floors + invented-name list: the toolkit's reconciled `_shared/floors-master.md` and
  `_shared/hallucination-blacklist.md` (re-confirmed 2026-06-07).
- Apple — Accessibility modifiers: `https://sosumi.ai/documentation/swiftui/view-accessibility` and
  `https://sosumi.ai/documentation/swiftui/view/accessibilitylabel(_:)` (fetch via Sosumi; access 2026-06-07).
- Practice shapes from the bundled `swiftui-ctx` corpus (`lookup accessibilityLabel` / `accessibilityElement`,
  2026-06-07) — every result GitHub-permalinked.
