# Phase / keyframe / symbol motion (anim-05 · anim-06 · anim-07)

The macOS-14 motion primitives that retire hand-rolled animation loops: **`PhaseAnimator`**,
**`KeyframeAnimator`**, **`.symbolEffect`**, and the value-aware **`.contentTransition`** (macOS 13). Floor
values are the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

## anim-05 — hand-rolled loop where `PhaseAnimator` / `KeyframeAnimator` fits (macOS 14)

A `Timer`, an `onAppear` that toggles `@State` to drive `.repeatForever`, or a chain of nested
`withAnimation(completion:)` calls to sequence steps is the pre-14 way to build multi-step motion. macOS 14
replaced it:

- **`PhaseAnimator`** — cycles a view through an ordered set of discrete phases (pulse, shake, attention).
- **`KeyframeAnimator`** — animates multiple properties along independent timelines from real keyframes.

Advisory — whether the motion is better expressed as phases is a judgment, so flag the ✅.

```swift
// ⚠️ hand-rolled repeating pulse
.scaleEffect(pulsing ? 1.1 : 1.0)
.animation(.easeInOut.repeatForever(autoreverses: true), value: pulsing)
.onAppear { pulsing = true }
// ✅ PhaseAnimator (macOS 14)
.phaseAnimator([1.0, 1.1]) { view, scale in view.scaleEffect(scale) }
```

## anim-06 — `.symbolEffect` ungated, or hand-animated SF Symbol where it fits (macOS 14)

`.symbolEffect(_:options:value:)` / `(_:options:isActive:)` is **macOS 14.0+**. Two defects: (a) it is used
**ungated** under a < macOS 14 floor → gate `#available(macOS 14, *)` on the macOS arm
(`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`); (b) an SF Symbol is animated by hand
(rotation/opacity `withAnimation`) where a built-in `.symbolEffect` (`.bounce`, `.pulse`, `.variableColor`,
`.rotate`) is the native, accessibility-aware path.

- **swiftui-ctx** (`swiftui-ctx lookup symbolEffect --json`): `introduced_macos` **14**; consensus spreads
  across `(_)`, `(_, isActive)`, `(_, value)` — pick the value/isActive form that matches the trigger state.

## anim-07 — value change without `.contentTransition` (macOS 13)

A `Text` showing a number/score, a counter, or a swapped SF Symbol that changes value with no
`.contentTransition(_:)` cross-fades crudely. macOS 13 added `.contentTransition(.numericText())` (digit
roll), `.opacity`, `.interpolate`, and `.symbolEffect`. Advisory — flag where a value mutation animates
without it.

```swift
// ✅ rolling numeric text on value change
Text(score, format: .number)
    .contentTransition(.numericText())
    .animation(.snappy, value: score)
```

## VERIFY (step 5)

- Practice: `swiftui-ctx lookup symbolEffect --json` (floor 14, consensus shapes, `recommended` permalink);
  `swiftui-ctx lookup contentTransition --json`. FIX cites the consensus shape + a `file <id> --smart`
  GitHub permalink as the ✅.
- Spec: Sosumi for `PhaseAnimator` / `KeyframeAnimator` / `symbolEffect` floors; cross-check `floors-master.md`.

## Sources

- Floors: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (Apple-sourced via Sosumi, 2026-06-07).
- Apple — `PhaseAnimator`: `https://developer.apple.com/documentation/swiftui/phaseanimator` (via Sosumi,
  2026-06-07).
- Apple — `KeyframeAnimator`: `https://developer.apple.com/documentation/swiftui/keyframeanimator` (via
  Sosumi, 2026-06-07).
- Apple — `View.symbolEffect(_:options:value:)`:
  `https://developer.apple.com/documentation/swiftui/view/symboleffect(_:options:value:)` (via Sosumi,
  2026-06-07).
- Apple — `View.contentTransition(_:)`:
  `https://developer.apple.com/documentation/swiftui/view/contenttransition(_:)` (via Sosumi, 2026-06-07).
