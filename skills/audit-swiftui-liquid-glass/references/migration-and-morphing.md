# Reference — Migration Regressions & Morph Wiring

The two migration regressions the auto-glass model drops (Tab/`@SceneStorage` restoration, the
auto-removable `LabelStyle`) and the morph-wiring conditions for `glassEffectID` / `glassEffectUnion`.
Floors live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; real symbols in
`glass-api-surface.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## Migration regressions

**glass-15 — `Tab(...)` adopted, selection not `@SceneStorage`-backed (advisory, flag-only).**
The Liquid Glass tab look depends on the new `Tab(...)` struct; once you adopt it, tab-selection **state
restoration is no longer automatic**. Selection bound to plain `@State` is lost on relaunch.
```swift
// ❌ selection lost across relaunch
@State private var selection: TabID = .home
// ✅ restore across relaunch
@SceneStorage("selectedTab") private var selection: TabID = .home
```
Flag-only — adding `@SceneStorage` changes persistence semantics (the dev decides the key).

**glass-16 — backward-compat `LabelStyle` kept after raising the floor to 26 (advisory; fix_mode:
auto).** Once the deployment target is macOS 26, glass styles the items and a hand-rolled backward-compat
`LabelStyle` is dead code. Annotation-only fix — makes the compiler force its removal without changing
behavior:
```swift
@available(macOS, obsoleted: 26, message: "Glass styles items on macOS 26 — remove this LabelStyle.")
struct LegacyToolbarLabelStyle: LabelStyle { … }
```
Safe to auto-fix: it adds an annotation, it does not delete or rewrite the type.

---

## Morph wiring (`glassEffectID`)

**glass-17 — broken morph (advisory, flag-only).** A morph silently no-ops unless **all four**
conditions hold; AI commonly supplies the `id` but drops one:
1. all morphing views share **one** `GlassEffectContainer`;
2. they share a **`@Namespace`**;
3. the state change is wrapped in **`withAnimation`**;
4. the change is a **conditional render** (add/remove the view) — not just `.opacity(0)` / `.hidden()`.
Name the missing condition in the finding.

```swift
@Namespace private var ns
GlassEffectContainer {
    if showDetail {                                  // conditional render, not opacity
        DetailControl().glassEffect().glassEffectID("detail", in: ns)
    }
}
.onTapGesture { withAnimation { showDetail.toggle() } }   // animated state change
```

## Union (`glassEffectUnion`)

**glass-18 — union across mismatched siblings (advisory, flag-only).** `glassEffectUnion(id:namespace:)`
only merges siblings that share the **same shape AND the same Liquid Glass variant** (Apple) **and the
same tint** (practitioner-corroborated, now Apple-confirmed). Differing shape/variant/tint → they won't
merge. ✅ make `id`, shape, glass variant, and tint identical across the union.

---

## Sources

- Apple — `glassEffectUnion(id:namespace:)` discussion ("same shape and Liquid Glass variant"
  grouping), macOS 26.0+: `https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:)`
  (via Sosumi, accessed 2026-06-07).
- Apple — `glassEffectID(_:in:)` / `glassEffectTransition(_:)`, macOS 26.0+
  (`/documentation/swiftui/view/glasseffectid(_:in:)`, via Sosumi, 2026-06-07).
- Majid Jabrayilov — "Liquid Glass in SwiftUI": Tab + `@SceneStorage` restoration;
  `@available(macOS, obsoleted: 26)` `LabelStyle` auto-removal; migration not backward-compatible.
  `https://swiftwithmajid.com/2025/07/01/liquid-glass-in-swiftui/` (accessed 2026-06-07, high trust).
- Donny Wals — `glassEffectUnion` grouping conditions (same id / glass style / tint), now
  Apple-corroborated: `https://donnywals.com/grouping-liquid-glass-components-using-glasseffectunion-on-ios-26/`
  (accessed 2026-06-07, high trust).
