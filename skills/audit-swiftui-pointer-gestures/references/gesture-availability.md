# Pointer-modifier availability gating (pg-07, pg-12)

This skill owns **pointer-modifier** gating in depth; the blanket "is every floored API gated" sweep is
`audit-swiftui-availability-gating`'s (cross_ref it when a gate miss is incidental). The *rule* for
writing a macOS gate, the wrong-arm failure mode, and reading a multi-platform availability string are the
**single shared copy** in `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` — read it, do not
restate it here. Floor *values* live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

---

## Which pointer modifiers need a gate

Only two of this domain's APIs have a floor above the common Mac deployment target, so only these trigger
pg-07 when the project floor is below them (read the value from `floors-master.md`, never assert it):

- `pointerStyle(_:)` / `PointerStyle` (incl. `.grabActive`/`.grabIdle`/`.columnResize`/`.rowResize`/
  `.frameResize(position:directions:)`) — the higher floor; **no iOS arm** (Mac-only).
- `onContinuousHover(coordinateSpace:perform:)` — the lower of the two.

`.onHover` and `.contextMenu` are macOS 10.15+ and effectively never need a gate; `MagnifyGesture` /
`RotateGesture` are macOS 14.0+ (gate only under a sub-14 floor — see `gestures-and-state.md`).

## pg-07 — an ungated pointer modifier under a lower floor (warning)

If the deployment target (read in ORIENT) is **below** the modifier's floor and the call is not wrapped in
`#available(macOS NN, *)` (or annotated `@available`), it is a build break / silent no-op. Report pg-07
**only** when the floor is actually below; at or above the floor it is not a finding. Use the macOS arm and
the trailing `*` per the shared rule. The pre-floor `else` (where the affordance must degrade) drops the
cursor shape gracefully — there is no pre-15 `pointerStyle` equivalent, so the fallback is simply omitting
the cursor change, not a substitute API.

```swift
// ✅ CORRECT — gated on the macOS arm; pre-15 path just omits the cursor shape
if #available(macOS 15, *) {
    handle.pointerStyle(.columnResize(directions: .all))
} else {
    handle                                  // no cursor change pre-15 (no equivalent API)
}
```

## pg-12 — a pointer modifier gated on the `iOS` arm (wrong arm, hard-fail, auto)

Gating a Mac-only / Mac-floored pointer modifier on the **iOS** arm is the central gating bug: on a Mac
the branch's availability is wrong, so it either fails to compile or silently never runs. The symbol is
fine; the **arm** is wrong — flag it as a gating finding, not a hallucination, and rewrite to
`#available(macOS NN, *)`. `fix_mode: auto`. The tier-2 ast-grep rule `pg-12-ios-arm-gates-pointer.yml`
proves the `if #available(iOS …)` block body actually uses `pointerStyle` / `onContinuousHover` (the gate
*scope*), not merely that the `iOS` string appears.

```swift
// ❌ WRONG — pointerStyle is Mac-only; gating it on iOS means it never runs on the Mac
if #available(iOS 18, *) { handle.pointerStyle(.grabIdle) }
```
```swift
// ✅ CORRECT — the macOS arm and floor
if #available(macOS 15, *) { handle.pointerStyle(.grabIdle) }
```

Full rule (macOS arm, the required `*`, reading a multi-platform string, the `macOS ABSENT` case): the
shared `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`. Note `pointerStyle` has **no iOS
arm at all** — it is `macOS-only`, so an `iOS`-armed gate around it is always wrong-arm, never a higher-iOS
over-gate.

---

## Detection tells (what LOCATE surfaces; you READ and judge)

- `.pointerStyle(` / `onContinuousHover(` present **and** project floor below the modifier's floor, with
  no enclosing `#available(macOS NN, *)` → pg-07 (read the floor in ORIENT).
- `#available(iOS …)` whose block body uses `pointerStyle` / `onContinuousHover` → pg-12 (tier-2 proves
  the scope).

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:) | `pointerStyle(_:)` — macOS 15.0+, macOS-only (no iOS arm) | high |
| https://developer.apple.com/documentation/swiftui/view/oncontinuoushover(coordinatespace:perform:) | `onContinuousHover` — macOS 14.0+ | high |
| https://developer.apple.com/documentation/swiftui/pointerstyle | `PointerStyle` — `.grabActive`/`.grabIdle`/`.columnResize`/`.rowResize`/`.frameResize(position:directions:)`; macOS 15.0+ | high |

Apple availability strings cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
and fetched via Sosumi (access 2026-06-07). The macOS-arm gating *rule* itself is the shared
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` — not restated here.
