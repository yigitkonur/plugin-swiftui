# Reference — macOS-ABSENT Symbols & Floor Quirks (gate-06 · gate-08)

Two ways a gate goes wrong that are *not* "wrong floor": a symbol that has no Mac arm at all (so it can
never be gated onto the Mac — it must be replaced), and a floor that the docs render misleadingly (so the
gate value you'd read is wrong). The canonical macOS-ABSENT / invented-name list is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read it, do not restate it here.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## gate-06 — macOS-ABSENT symbol wrapped in a Mac gate (hard-fail; fix_mode: flag-only)

A `macOS ABSENT` symbol has no macOS arm in its availability string. Wrapping it in
`#available(macOS …)` is doubly wrong: the gate cannot summon a symbol the Mac SDK does not ship, and on
a Mac target the call is a compile error or a no-op. The fix is to **replace** it with the Mac
equivalent — never to gate it. Per `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` §3,
if macOS is absent from the array the symbol is *platform-wrong*, not under-gated.

| macOS-ABSENT symbol | Mac equivalent |
|---|---|
| `.glassBackgroundEffect()` (visionOS) | `.glassEffect()` (macOS 26.0+, gated) |
| `WheelPickerStyle` | `.menu` (macOS 11.0+; gate if target < 11) / `.segmented` / default `PickerStyle` |
| `ToolbarItemPlacement.topBarLeading` / `.topBarTrailing` | `.navigation` / `.primaryAction` / `.automatic` |
| `WindowStyle.volumetric` (visionOS) | `.automatic` / `.hiddenTitleBar` window style |
| `navigationBarTitleDisplayMode(_:)` | `.navigationTitle(_:)` (+ `.navigationSubtitle` on macOS) |
| `.bottomBar` toolbar placement | `.automatic` / a bottom `.safeAreaInset` |

```swift
// ❌ gating a symbol that has no Mac arm — it will never resolve on macOS
if #available(macOS 26.0, *) { picker.pickerStyle(WheelPickerStyle()) }
// ✅ replace with a Mac picker style (.menu is macOS 11.0+; gate it if target < 11)
picker.pickerStyle(.menu)
```

flag-only: which equivalent fits is a design call. Confirm absence with `swiftui-ctx lookup <api> --json`
(an **exit 3** / no `introduced_macos` for macOS corroborates it) + Sosumi.

---

## gate-08 — the DocC type-property floor quirk (advisory; fix_mode: flag-only)

A type-property's DocC page can render the **type's** availability, not the **property's** — so the floor
you'd copy into a gate is wrong. The headline case carried in floors-master: a property introduced later
than its enclosing type, or a static member whose page inherits the type's "first available" badge.
Always re-confirm a **type-property** floor against Sosumi (and `swiftui-ctx introduced_macos`) rather
than trusting the page's top-of-page availability badge. Carry an unconfirmable type-property floor as
`advisory` with `source: verify against Xcode 26 SDK`.

There is no flat lint tell for gate-08 — it surfaces during the VERIFY floor cross-check whenever a
gate-01/gate-03 candidate is a type-property whose floor you cannot place from memory.

**Sosumi fetch caution (`.task`-family):** some doc paths — notably `.task(_:)` / `.task(id:_:)` and a
few modifier overload pages — return an SPA shell rather than rendered content on first fetch. Retry, or
use the JSON availability endpoint per `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`,
before concluding a floor "couldn't be confirmed."

---

## Sources

- The macOS-ABSENT / invented-name list + Mac equivalents:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` and the reading-the-string rule
  in `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` §3 (toolkit-internal, Apple-sourced
  via Sosumi, access 2026-06-07).
- Floor values + the type-property quirk: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.
- Apple — `pickerStyle(_:)` / `PickerStyle` macOS availability:
  `https://developer.apple.com/documentation/swiftui/view/pickerstyle(_:)` (via Sosumi, accessed
  2026-06-07).
- The Swift `#available` / `@available` language feature (`swift.org`).
