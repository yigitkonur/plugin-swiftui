# Shared Reference — Hallucination Blacklist (nonexistent APIs → real replacements)

The canonical list of invented/nonexistent or platform-wrong API names that AI models emit as
plausible-looking SwiftUI, each with the **real** macOS replacement. A match on any blacklisted
name is **always a hard-fail** (it will not compile or is a silent no-op). This is shared *data*:
`api-currency` owns authoring it, the pre-ship gate's hallucination sweep reads it, and
`liquid-glass`, `charts`, `pointer-gestures` consume the relevant rows. Do not restate this list
inside a skill's own `references/`.

To confirm a symbol's existence/availability before flagging, fetch the Apple page via
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`. Floors for the *real* replacements
live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## 1. Liquid Glass — invented modifiers & types

| Hallucinated / wrong | Why it's wrong | Real replacement (macOS) |
|---|---|---|
| `.glassBackground()` | Does not exist. | `.glassEffect(_:in:)` (macOS 26.0+) |
| `.liquidGlass()` | Does not exist — marketing name, not an API. | `.glassEffect(_:in:)` (macOS 26.0+) |
| `LiquidGlassView` | No such view type. | `GlassEffectContainer { … }` (macOS 26.0+) |
| `.material(.glass)` | `Material` has no `.glass` case. | `.glassEffect(.regular, in:)` or `.background(.ultraThinMaterial)` for pre-26 fallback |
| `.glassEffect(.liquid)` | `Glass` has no `.liquid` static. | `Glass.regular` / `.clear` / `.identity` (macOS 26.0+) |
| `GlassContainer` | Wrong name. | `GlassEffectContainer` (macOS 26.0+) |
| `.buttonStyle(.liquidGlass)` | No such style. | `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` (macOS 26.0+) |
| `.glassBackgroundEffect()` on a Mac path | Real symbol, but **visionOS-only — macOS ABSENT**. | `.glassEffect(_:in:)` on macOS 26.0+ |

> **`.interactive()` is NOT iOS-only.** `Glass.interactive(_:)` IS available on macOS 26.0+
> (pointer-driven). Do not flag it as a hallucination; flag a *wrong-arm gate* if it is gated on
> `#available(iOS 26, *)` in a macOS path (see `macos-arm-gating.md`).

---

## 2. Focus / document — phantom property wrappers

| Hallucinated / wrong | Why it's wrong | Real replacement (macOS) |
|---|---|---|
| `@FocusedDocument` | **Not a real Apple symbol.** | A custom `FocusedValues` key: `@Entry var focusedDocument: …` (on `FocusedValues`) + `@FocusedValue(\.focusedDocument)`. |
| `@FocusedBinding` used as a wrapper that does not exist | (`@FocusedBinding` *does* exist) — verify the key exists before flagging. | confirm via Sosumi; real keys come from `FocusedValueKey` / `@Entry` on `FocusedValues`. |

---

## 3. Pointer / gesture — stale or invented case names

| Hallucinated / wrong | Why it's wrong | Real replacement (macOS) |
|---|---|---|
| `PointerStyle.grabbing` | Stale/invented case name. | `PointerStyle.grabActive` / `.grabIdle` (macOS 15.0+) |
| `pointerStyle(.grabbing)` | Same — no `.grabbing` case. | `.pointerStyle(.grabActive)` (macOS 15.0+) |
| `MagnificationGesture` as the *current* API | Real but **deprecated** (26.5). | `MagnifyGesture` (macOS 14.0+) |
| `RotationGesture` as the *current* API | Real but **deprecated** (26.5). | `RotateGesture` (macOS 14.0+) |

---

## 4. Charts — invented mark/plot names

| Hallucinated / wrong | Why it's wrong | Real replacement (macOS) |
|---|---|---|
| `PieMark` | No such mark — pie/donut is built from sectors. | `SectorMark` (macOS 14.0+) |
| `DonutMark` | No such mark. | `SectorMark` with `innerRadius:` (macOS 14.0+) |
| `ScatterMark` | No such mark. | `PointMark` (macOS 13.0+) |
| `ColumnMark` | No such mark. | `BarMark` (macOS 13.0+) |

---

## 5. Toolbar / navigation — platform-wrong placements

| Hallucinated / wrong | Why it's wrong | Real replacement (macOS) |
|---|---|---|
| `ToolbarItemPlacement.topBarLeading` / `.topBarTrailing` on a Mac target | **macOS ABSENT — compile error.** iOS-shaped. | `.navigation` / `.primaryAction` (macOS 11.0+) |
| `.navigationBarTitleDisplayMode(...)` on macOS | No macOS arm. | omit — use `.navigationTitle` / `.navigationSubtitle` |

---

## How to use this list

1. **Sweep, case-sensitive.** A literal match on a left-column name is a finding.
2. **Always hard-fail.** Hallucinated APIs do not compile or silently no-op; severity is
   `hard-fail` with `fix_mode: auto` only when the replacement is a mechanical 1:1 rename.
3. **Verify before flagging a near-miss.** If a name *looks* invented but might be a real new
   symbol, confirm via Sosumi (`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`)
   before emitting — never assert nonexistence from memory.

---

## Sources

- `developer.apple.com` SwiftUI / Charts symbol pages + JSON availability endpoints (access date
  **2026-06-07**), fetched via Sosumi — confirming the *real* replacement symbols exist and the
  blacklisted names do not.
- WWDC25 Liquid Glass sessions (via Sosumi) for the glass API surface.
