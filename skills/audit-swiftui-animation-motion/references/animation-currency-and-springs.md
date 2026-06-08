# Animation currency & spring presets (anim-01 · anim-02 · anim-03 · anim-04)

The currency layer of motion: the **deprecated implicit `.animation(_)`**, the **missing/wrong `value:`**,
**raw durations where a spring preset belongs**, and the **spring-preset floor quirk**. Floor *values* are
the reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate.

## anim-01 — implicit single-arg `.animation(_)` (deprecated at macOS 12)

`.animation(_:)` with one argument was **deprecated at macOS 12.0**: it implicitly animates *every*
upstream change, which is unpredictable. The fix is the **value-scoped** form `.animation(_:value:)` or an
explicit `withAnimation`. The production corpus agrees overwhelmingly.

- **swiftui-ctx consensus** (`swiftui-ctx lookup animation --json`): **92 % `(_, value)`**, only **7 % `(_)`**,
  1 % `()`. The modern value-scoped form is the consensus shape — get it live, don't paste a stale one.

```swift
// ❌ implicit — animates any change reaching this view (deprecated macOS 12)
Circle().scaleEffect(scale).animation(.easeInOut)

// ✅ value-scoped — the swiftui-ctx consensus shape `(_, value)` (92 %); the recommended real example:
//    sindresorhus/Gifski (author_authority 1,013,769, 8,409★) — fetch with
//    `swiftui-ctx file ex_7f40920aa8 --smart`
//    permalink: https://github.com/sindresorhus/Gifski/blob/7f873856e2acd8b52e6681dee3aec31e6cab23e4/Gifski/Utilities.swift#L4974
//    doc: https://sosumi.ai/documentation/swiftui/view/animation
Circle().scaleEffect(scale)
    .animation(.easeInOut(duration: 0.3), value: scale)
```

For animations that must coordinate a multi-property state change, prefer the imperative `withAnimation`
around the mutation instead of an implicit modifier.

## anim-02 — animating a constant, or `withAnimation` over no observed change

`.animation(_:value:)` only fires when `value` actually changes. Two real defects: (a) `value:` bound to a
**constant** or a value the body never reads → the animation is dead; (b) `withAnimation { … }` whose body
mutates **no `@State`/observed** property → nothing animates. READ the surrounding state to confirm the
`value` is the property the visual actually depends on.

## anim-03 — raw duration curve where a spring preset fits (macOS 14)

Hand-tuned `.linear(duration:)` / `.easeInOut(duration:)` for interactive, physical motion (drags, toggles,
appearance) reads non-native. macOS 14 shipped the **named spring presets** `.bouncy` / `.smooth` /
`.snappy`, which adapt to interruption. Advisory — the curve is a judgment, so flag the ✅, don't auto-apply.

```swift
// ⚠️ raw curve for a physical interaction
withAnimation(.easeInOut(duration: 0.35)) { isExpanded.toggle() }
// ✅ a spring preset (macOS 14)
withAnimation(.smooth) { isExpanded.toggle() }
```

## anim-04 — spring preset ungated under a < macOS 14 floor (the DocC quirk)

`Animation.bouncy` / `.smooth` / `.snappy` are **macOS 14.0+** even though the shipped DocC renders
`macOS 10.15` — a **type-property-inheritance quirk** (the property inherits its enclosing `Animation`
type's 10.15 floor; the WWDC23 provenance is the truth). If the project's deployment target is below
macOS 14 and a preset is used **ungated**, it is a real availability break — **hard-fail**. Confirm the
floor in ORIENT, then gate `#available(macOS 14, *)` on the macOS arm
(`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`). Suppress when the floor is already ≥ 14.

> Never trust the rendered 10.15 for spring presets. Carry the floor as the reconciled **macOS 14**.

## VERIFY (step 5)

- Practice: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup animation --json` — read `consensus`
  (the 92 % `(_, value)` shape), `deprecated`, `introduced_macos`, `recommended` (the canonical permalink).
- Spec: Sosumi `https://sosumi.ai/documentation/swiftui/view/animation` for the deprecation badge + the
  `animation(_:value:)` signature; the spring-preset floor against `floors-master.md`.

## Sources

- Floor/deprecation values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (Apple-sourced via
  Sosumi, access 2026-06-07).
- Apple — `View.animation(_:value:)`:
  `https://developer.apple.com/documentation/swiftui/view/animation(_:value:)` (via Sosumi, 2026-06-07).
- Apple — deprecated `View.animation(_:)`:
  `https://developer.apple.com/documentation/swiftui/view/animation(_:)` (via Sosumi, 2026-06-07).
- Apple — `Animation.bouncy/.smooth/.snappy` (macOS 14, WWDC23 "Animate with springs"):
  `https://developer.apple.com/documentation/swiftui/animation/smooth` (via Sosumi, 2026-06-07).
