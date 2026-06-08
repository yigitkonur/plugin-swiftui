# Labels, decorative hiding, traits, floor-gating (a11y-01/02/08/12)

How the *perceivable identity* and *operable trait* of a control are announced — and the floor gates that
guard newer trait/label forms. Floors are in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

## a11y-01 — icon-only control with no label (warning, flag-only)

An icon-only `Button` (or any tappable whose only content is `Image(systemName:)` / a `Label` with no
visible text) announces the raw SF Symbol name ("plus.circle.fill") or nothing. VoiceOver users cannot tell
what it does.

```
// ❌ icon-only, unlabeled
Button { add() } label: { Image(systemName: "plus") }
// ✅ labeled (consensus shape: trailing string, pct 100 — swiftui-ctx lookup accessibilityLabel)
Button { add() } label: { Image(systemName: "plus") }
    .accessibilityLabel("Add item")
```

**Reuse the `.help` text.** If `audit-swiftui-controls-forms` already authored a `.help("Add item")` tooltip
for this control, reuse that exact string as the label (emit `cross_ref controls-forms`). A `Label("Add",
systemImage: "plus")` with *visible* text is already accessible — not a finding. The canonical real example:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file ex_e9a36e4789 --smart` →
`.accessibilityLabel(item.displayName)` in `jordanbaird/Ice` (28k★, min_macos 26).

## a11y-02 — decorative image not hidden (advisory, flag-only)

A purely-decorative `Image` (a background flourish, a separator glyph, a redundant icon next to its own text
label) should be removed from the VoiceOver tree so it doesn't add noise:

```
Image("sparkle-divider").accessibilityHidden(true)
// or, for a non-asset decorative SF Symbol next to text it duplicates:
Label { Text("Favorites") } icon: { Image(systemName: "star") }   // icon already covered by the text — fine
```

Judgment call: only flag images that carry **no** information. `Image(decorative:)` initializer already hides
it. READ the surrounding view before flagging.

## a11y-08 — tappable without an actionable trait (warning, flag-only)

`.onTapGesture` / `.onLongPressGesture` on a `Text`/`HStack`/`Image` makes it interactive visually but leaves
VoiceOver with **no actionable trait** — the user never learns it's tappable. Prefer a real `Button`; if a
gesture is unavoidable, add the trait and an action:

```
// ❌ invisible to VoiceOver as a control
HStack { … }.onTapGesture { select() }
// ✅
HStack { … }
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { select() }
```

For a custom toggle, use `.isToggle` (see a11y-12 floor) + `.accessibilityValue("On"/"Off")`.

## a11y-12 — newer trait/label form ungated under a lower floor (hard-fail, flag-only)

Two forms are **newer than the rest of the accessibility surface** and break the build (or silently no-op on
older runtimes) if used under a lower deployment target:

| Form | Floor | Gate if floor below |
|---|---|---|
| `AccessibilityTraits.isToggle` | **macOS 14.0** (NOT 10.15) | `if #available(macOS 14, *) { … .accessibilityAddTraits(.isToggle) }` |
| `accessibilityLabel(content:)` closure | macOS 15.0 | gate or use the string form |
| `accessibilityValue(_:isEnabled:)` closure | macOS 15.0 | gate or use the plain form |

This fires **only** when ORIENT read a floor below the form's floor. Gate on the **macOS** arm (never `iOS`)
per `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`. The blanket "is every floored API gated"
sweep is `audit-swiftui-availability-gating`'s; this skill owns only the accessibility-specific forms above.

## Go-beyond — the coverage map

Optional `swiftui-audits/accessibility/_coverage-map.md`: one row per interactive view with columns
*label · value · trait · grouped? · axis* and a per-axis (`perceivable`/`operable`/`grouped`/`represented`)
coverage score. Lets a reviewer see at a glance which controls are silent to VoiceOver.

## Sources

- Apple — `accessibilityLabel(_:)` / `accessibilityAddTraits(_:)` / `accessibilityHidden(_:)`:
  `https://sosumi.ai/documentation/swiftui/view/accessibilitylabel(_:)`,
  `https://sosumi.ai/documentation/swiftui/view/accessibilityaddtraits(_:)` (via Sosumi; access 2026-06-07).
- `AccessibilityTraits.isToggle` floor (macOS 14): `_shared/floors-master.md` (re-confirmed 2026-06-07).
- Real label example: `jordanbaird/Ice` IceBar.swift L406 — via `swiftui-ctx file ex_e9a36e4789 --smart`.
- Apple HIG — Accessibility: `https://sosumi.ai/design/human-interface-guidelines/accessibility` (access 2026-06-07).
