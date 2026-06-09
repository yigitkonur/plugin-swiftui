# Reference — The Gating Defects (gate-01 · gate-02 · gate-03 · gate-04 · gate-05 · gate-07)

The depth for the blanket availability sweep. This skill is the toolkit's **net**: every API floored
above the project's deployment target must be gated on the macOS arm, at the right floor, with a real
fallback. The cross-cutting *rule* (the macOS arm, the required `*` wildcard, the wrong-arm failure,
reading multi-platform strings) is **not** restated here — it lives in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`. Floor *values* are the reconciled truth
in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — that table **is** this skill's floor
map. This file adds the per-defect application and the ❌→✅ rewrites.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## The fact that drives every finding: the deployment target

Read it once in ORIENT (`MACOSX_DEPLOYMENT_TARGET` in `project.pbxproj`, or `platforms:` in
`Package.swift`). A symbol floored at macOS NN is a finding **only** when the target is **below NN**.
Mac users lag on OS upgrades, so shipping apps legitimately target an older macOS *and* macOS 26 — that
dual target is exactly why the gate is required. A symbol whose floor is ≤ the target is **not** a
finding; suppress it.

---

## gate-01 — ungated above-floor symbol (hard-fail; fix_mode: flag-only)

The symbol is used with no `#available`/`@available` guard, and its floor (per floors-master) is above
the deployment target → the build breaks on the older macOS the project claims to support. flag-only
because the right `else` fallback is a judgment.

```swift
// ❌ MACOSX_DEPLOYMENT_TARGET = 14.0; glassEffect is macOS 26.0+ → build error on 14/15
controls.glassEffect()
// ✅ macOS arm + a pre-floor fallback (the consensus gated shape — see ## Source)
if #available(macOS 26.0, *) {
    controls.glassEffect(in: .capsule)
} else {
    controls.background(.ultraThinMaterial, in: Capsule())
}
```

Confirm the floor with `swiftui-ctx lookup <api> --json` (`introduced_macos`) and Sosumi before
reporting. If the symbol is *also* deprecated, it is an **api-currency** finding — `cross_ref` it, don't
double-report (per `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`). If it is a glass
symbol, `cross_ref: audit-swiftui-liquid-glass` (it owns glass gating in depth).

---

## gate-02 — wrong-arm gate (hard-fail; fix_mode: auto)

```swift
// ❌ the wildcard * already covers macOS, so this branch always runs and the macOS floor is never
//    enforced — the call ships unguarded on a Mac.
if #available(iOS 26.0, *) { controls.glassEffect() }
// ✅ pure arm correction
if #available(macOS 26.0, *) { controls.glassEffect() }
```

Safe to auto-fix because only the arm is wrong; floor and structure are otherwise correct. Per
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` §2 this is a gating finding, **not** a
hallucination — `Glass.interactive(_:)` and the like are real on macOS 26.0; the arm is the bug.

---

## gate-03 — floor mismatch (warning; fix_mode: flag-only)

A `#available(macOS NN, *)` gate exists but `NN` ≠ the symbol's floor in floors-master. Two shapes:

- **Over-gating** — `NN` higher than the floor needlessly excludes Macs that support the symbol (e.g.
  gating `navigationSubtitle` at `macOS 26` when it is `macOS 11.0+` — the iOS floor is 26 but the Mac
  floor is 11; reading the iOS arm over-gates the Mac, per macos-arm-gating §3).
- **Under-gating** — `NN` lower than the floor still breaks the build (e.g. `glassEffect` gated at
  `macOS 15`). flag-only: the dev picks whether to raise the gate or change the API.

Always read the **macOS** arm of the availability string — never the iOS number. Verify with
`swiftui-ctx lookup <api>` (`introduced_macos`) + Sosumi.

---

## gate-04 — missing else fallback (warning; fix_mode: flag-only; no flat lint tell)

An `if #available(macOS NN, *)` with **no `else`** is legal Swift, but if the gated branch produces a
*view the layout depends on*, the pre-floor OS renders nothing there. A missing `else` is structural
absence ast-grep cannot positively match, so there is no flat tell — you decide in READ from each
gate-03 hit (every located `#available(macOS …)`): does this branch contribute a control/surface the UI
needs pre-floor? If yes, a fallback is required.

```swift
// ❌ pre-26 the pill simply vanishes
if #available(macOS 26.0, *) { pill.glassEffect(in: .capsule) }
// ✅ a real pre-floor fallback
if #available(macOS 26.0, *) {
    pill.glassEffect(in: .capsule)
} else {
    pill.background(.ultraThinMaterial, in: Capsule())
}
```

A purely additive decoration (the surface is fine flat pre-floor) needs no `else` — don't over-report.

---

## gate-05 — @available decl vs #available use mismatch (warning; fix_mode: flag-only)

`@available(macOS NN, *)` on a `type`/`func`/`var` gates the *declaration*; the **use site** still needs
its own `#available` (or an `@available` on its container). The defects:

- a type/function annotated `@available(macOS 26, *)` is *called* from an ungated context;
- a use site `#available(macOS 26, *)` whose declaration carries **no** `@available`, so the symbol is
  reachable from a sub-floor caller;
- the decl and use floors **disagree** (`@available(macOS 26)` decl, `#available(macOS 15)` use).

```swift
// ✅ both layers agree, on the macOS arm
@available(macOS 26.0, *)
struct GlassPill: View { var body: some View { … } }

if #available(macOS 26.0, *) { GlassPill() } else { LegacyPill() }
```

flag-only: which layer to move (raise the use gate vs add a decl gate) is a design call.

---

## gate-07 — missing `*` wildcard (hard-fail; fix_mode: auto)

```swift
if #available(macOS 26.0) { … }    // ❌ compile error — no trailing wildcard
if #available(macOS 26.0, *) { … } // ✅
```

The `*` covers every *other* platform the code may compile against and is mandatory. Auto-fixable: append
`, *` inside the condition. Same for `@available(macOS 26.0)` → `@available(macOS 26.0, *)`.

---

## Sources

- The gating rule, the `*` wildcard, the wrong-arm failure, multi-platform strings:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` (toolkit-internal, Apple-sourced via
  Sosumi, access 2026-06-07).
- Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (same provenance).
- Apple — `glassEffect(_:in:)` macOS 26.0+:
  `https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)` (via Sosumi, accessed
  2026-06-07).
- Consensus gated example: `swiftui-ctx lookup glassEffect` → `f/textream` `ContentView.swift#L73`
  (`min_macos: 26`): `https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/ContentView.swift#L73`
  (accessed 2026-06-07).
- The Swift `#available` / `@available` language feature (`swift.org`).
